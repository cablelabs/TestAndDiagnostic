#! /bin/sh

UTOPIA_PATH="/etc/utopia/service.d"
TAD_PATH="/usr/ccsp/tad"

source $UTOPIA_PATH/log_env_var.sh

exec 3>&1 4>&2 >>$SELFHEALFILE 2>&1

source $TAD_PATH/corrective_action.sh

rebootDeviceNeeded=0

LIGHTTPD_CONF="/var/lighttpd.conf"

rebootDeviceNeeded=0

	# Checking snmp subagent PID
	SNMP_PID=`pidof snmp_subagnet`
	if [ "$SNMP_PID" = "" ]; then
		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : snmp process is not running, need restart"
		resetNeeded snmp snmp_subagent 
	fi

	HOMESEC_PID=`pidof CcspHomeSecurity`
	if [ "$HOMESEC_PID" = "" ]; then
		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : HomeSecurity process is not running, need restart"
		resetNeeded "" CcspHomeSecurity 
	fi

	HOTSPOT_ENABLE=`dmcli eRT getv Device.DeviceInfo.X_COMCAST_COM_xfinitywifiEnable | grep value | cut -f3 -d : | cut -f2 -d" "`
	if [ "$HOTSPOT_ENABLE" = "true" ]
	then
	
		DHCP_ARP_PID=`pidof hotspot_arpd`
        if [ "$DHCP_ARP_PID" = "" ] && [ -f /tmp/hotspot_arpd_up ]; then
			echo "[`getDateTime`] RDKB_PROCESS_CRASHED : DhcpArp_process is not running, need restart"
			resetNeeded "" hotspot_arpd 
   		fi

	fi
	# Checking webpa PID
	WEBPA_PID=`pidof webpa`
	if [ "$WEBPA_PID" = "" ]; then
		ENABLEWEBPA=`cat /nvram/webpa_cfg.json | grep -r EnablePa | awk '{print $2}' | sed 's|[\"\",]||g'`
		if [ "$ENABLEWEBPA" = "true" ];then
		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : WebPA_process is not running, need restart"
			#We'll set the reason only if webpa reconnect is not due to DNS resolve
			syscfg get X_RDKCENTRAL-COM_LastReconnectReason | grep "Dns_Res_webpa_reconnect"
			if [ $? != 0 ]; then
				echo "setting reconnect reason from sysd_task_health_monitor.sh"
				echo "[`getDateTime`] Setting Last reconnect reason"
				syscfg set X_RDKCENTRAL-COM_LastReconnectReason WebPa_crash
				result=`echo $?`
				if [ "$result" != "0" ]
				then
					echo "SET for Reconnect Reason failed"
				fi
				syscfg commit
				result=`echo $?`
				if [ "$result" != "0" ]
				then
					echo "Commit for Reconnect Reason failed"
				fi
				echo "[`getDateTime`] SET succeeded"
			fi
			resetNeeded webpa webpa
		fi
	
	fi

	DROPBEAR_PID=`pidof dropbear`
	if [ "$DROPBEAR_PID" = "" ]; then
		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : dropbear_process is not running, restarting it"
		sh /etc/utopia/service.d/service_sshd.sh sshd-restart &
	fi
	
	# Checking lighttpd PID
	LIGHTTPD_PID=`pidof lighttpd`
	if [ "$LIGHTTPD_PID" = "" ]; then
		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : lighttpd is not running, restarting it"
		lighttpd -f $LIGHTTPD_CONF
	fi
	ifconfig | grep brlan1
	if [ $? == 1 ]; then
		echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : brlan1 interface is not up, need to reboot the unit" 
		rebootNeededforbrlan1=1
		rebootDeviceNeeded=1
	fi
	ifconfig | grep brlan0
	if [ $? == 1 ]; then
		echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : brlan0 interface is not up" 
		echo "[`getDateTime`] RDKB_REBOOT : brlan0 interface is not up, rebooting the device"
		echo "[`getDateTime`] Setting Last reboot reason"
		dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string brlan0_down
		echo "[`getDateTime`] SET succeeded"
		rebootNeeded RM ""
	fi

	ifconfig -a | grep l2sd0.100
    if [ $? == 1 ]; then
        echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : l2sd0.100 interface is not created try creating it"
        sysevent set multinet_1-status stopped
        $UTOPIA_PATH/service_multinet_exec multinet-start 1
        ifconfig -a | grep l2sd0.100
        if [ $? == 1 ]; then
           echo "[RKDB_PLATFORM_ERROR] : l2sd0.100 is not created at First Retry, try again after 2 sec"
           sleep 2
           sysevent set multinet_1-status stopped
           $UTOPIA_PATH/service_multinet_exec multinet-start 1
           ifconfig -a | grep l2sd0.100
           if [ $? == 1 ]; then
                echo "[RKDB_PLATFORM_ERROR] : l2sd0.100 is not created after Second Retry, no more retries !!!"
		   fi
        else
           echo "[RKDB_PLATFORM_ERROR] : l2sd0.100 Created at First Retry itself"
        fi
        logNetworkInfo 
    else
        ifconfig l2sd0.100 | grep UP
        if [ $? == 1 ]; then
           echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : l2sd0.100 interface is not up"
           logNetworkInfo
        fi
    fi  

    ifconfig -a | grep l2sd0.101
    if [ $? == 1 ]; then
        echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : l2sd0.101 interface is not created try creatig it" 
        sysevent set multinet_2-status stopped
        $UTOPIA_PATH/service_multinet_exec multinet-start 2
        ifconfig -a | grep l2sd0.101
        if [ $? == 1 ]; then
           echo "[RKDB_PLATFORM_ERROR] : l2sd0.101 is not created at First Retry, try again after 2 sec"
           sleep 2
           sysevent set multinet_2-status stopped
           $UTOPIA_PATH/service_multinet_exec multinet-start 2
           ifconfig -a | grep l2sd0.101
		    if [ $? == 1 ]; then
                echo "[RKDB_PLATFORM_ERROR] : l2sd0.101 is not created after Second Retry, no more retries !!!"
		    fi
        else
           echo "[RKDB_PLATFORM_ERROR] : l2sd0.101 created at First Retry itself"
        fi
    else
        ifconfig l2sd0.101 | grep UP
        if [ $? == 1 ]; then
           echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : l2sd0.101 interface is not up"
           fi
    fi

        SSID_DISABLED=0
        BR_MODE=0
        dmcli eRT getv Device.WiFi.SSID.2.Enable | grep "true"
        if [ $? == 1 ]
        then
            SSID_DISABLED=1
            echo "[`getDateTime`] [RDKB_SELFHEAL] : SSID 5GHZ is disabled"
            
        fi

        dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode | grep router
        if [ $? == 1 ]
        then
            BR_MODE=1
            echo "[`getDateTime`] [RDKB_SELFHEAL] : Device in bridge mode"
            
        fi

        if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED -eq 0 ]
        then
	    dmcli eRT getv Device.WiFi.SSID.2.Status | grep Up
	    if [ $? == 1 ]; then
		echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : 5G private SSID (ath1) is off."
		#dmcli eRT setv Device.X_CISCO_COM_DeviceControl.RebootDevice string Wifi
	    fi
        fi
        
	if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED -eq 0 ]
        then
	    dmcli eRT getv Device.WiFi.SSID.1.Status | grep Up
	    if [ $? == 1 ]; then
		echo "[`getDateTime`] [RKDB_PLATFORM_ERROR] : 2G private SSID (ath0) is off."
		#dmcli eRT setv Device.X_CISCO_COM_DeviceControl.RebootDevice string Wifi
	    fi
        fi
        
	WAN_STATE=`sysevent get wan_service-status`
	FIREWALL_ENABLED=`syscfg get firewall_enabled`

	echo "[`getDateTime`] [RDKB_SELFHEAL] : WAN_STATE is $WAN_STATE"
	echo "[`getDateTime`] [RDKB_SELFHEAL] : BRIDGE_MODE is $BR_MODE"
    echo "[`getDateTime`] [RDKB_SELFHEAL] : FIREWALL_ENABLED is $FIREWALL_ENABLED"

	if [ $BR_MODE -eq 0 ] && [ "$WAN_STATE" = "started" ]
	then
		iptables-save -t nat | grep "A PREROUTING -i"
		if [ $? == 1 ]; then
		echo "[`getDateTime`] [RDKB_PLATFORM_ERROR] : iptable corrupted."
		#sysevent set firewall-restart
		fi
	fi
	
	#All CCSP Processes Now running on Single Processor. Add those Processes to Test & Diagnostic 
	# Checking wifi subagent PID
	WIFI_PID=`pidof CcspWifiSsp`
	if [ "$WIFI_PID" = "" ]; then
		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : wifi process is not running, need restart"
		resetNeeded wifi CcspWifiSsp 
	fi
	
	if [ "$rebootDeviceNeeded" -eq 1 ]
	then
		cur_hr=`date +"%H"`
		cur_min=`date +"%M"`
		if [ $cur_hr -ge 02 ] && [ $cur_hr -le 03 ]
		then
			if [ $cur_hr -eq 03 ] && [ $cur_min -ne 00 ]
			then
				echo "Maintanance window for the current day is over , unit will be rebooted in next Maintanance window "
			else
			#Check if we have already flagged reboot is needed
				if [ ! -e $FLAG_REBOOT ]
				then
					if [ "$rebootNeededforbrlan1" -eq 1 ]
					then
						echo "rebootNeededforbrlan1"
						echo "[`getDateTime`] RDKB_REBOOT : brlan1 interface is not up, rebooting the device."
						echo "[`getDateTime`] Setting Last reboot reason"
						dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string brlan1_down
						echo "[`getDateTime`] SET succeeded"
						sh /etc/calc_random_time_to_reboot_dev.sh "" &
					else 
						echo "rebootDeviceNeeded"
						sh /etc/calc_random_time_to_reboot_dev.sh "" &
					fi
					touch $FLAG_REBOOT
				else
					echo "Already waiting for reboot"
				fi					
			fi
		fi
	fi
