#! /bin/sh

UTOPIA_PATH="/etc/utopia/service.d"
TAD_PATH="/usr/ccsp/tad"
RDKLOGGER_PATH="/rdklogger"

if [ -f /etc/device.properties ]
then
    source /etc/device.properties
fi
source /etc/log_timestamp.sh

ping_failed=0
ping_success=0
SyseventdCrashed="/rdklogs/syseventd_crashed"
PING_PATH="/usr/sbin"
WAN_INTERFACE="erouter0"
source $UTOPIA_PATH/log_env_var.sh


exec 3>&1 4>&2 >>$SELFHEALFILE 2>&1

source $TAD_PATH/corrective_action.sh

rebootDeviceNeeded=0

LIGHTTPD_CONF="/var/lighttpd.conf"

	# Checking PSM's PID
	PSM_PID=`pidof PsmSsp`
	if [ "$PSM_PID" = "" ]; then
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : PSM_process is not running, need to reboot the unit"
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : PSM_process is not running, need to reboot the unit"
#		vendor=`getVendorName`
#		modelName=`getModelName`
#		CMMac=`getCMMac`
#		timestamp=`getDate`
#		echo "[`getDateTime`] Setting Last reboot reason"
#		dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string Psm_crash
#		dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootCounter int 1
#		echo "[`getDateTime`] SET succeeded"
#		echo "[`getDateTime`] RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM PsmSsp process died,need reboot"
#		touch $HAVECRASH		
#		rebootNeeded RM "PSM"
		echo_t "RDKB_PROCESS_CRASHED : PSM_process is not running, need restart"
		resetNeeded psm PsmSsp
	fi
##################################
	if [ "$BOX_TYPE" = "XB3" ]; then
		  wifi_check=`dmcli eRT getv Device.WiFi.SSID.1.Enable`
		  wifi_timeout=`echo $wifi_check | grep "CCSP_ERR_TIMEOUT"`
		  if [ "$wifi_timeout" != "" ]; then
				  echo_t "[RDKB_SELFHEAL] : Wifi query timeout"
		  fi

		  SSH_ATOM_TEST=$(ssh root@$ATOM_IP exit 2>&1)
		  SSH_ERROR=`echo $SSH_ATOM_TEST | grep "Remote closed the connection"`
		  if [ "$SSH_ERROR" != "" ]; then
				  echo_t "[RDKB_SELFHEAL] : ssh to atom failed"
		  fi

		  if [ "$wifi_timeout" != "" ] && [ "$SSH_ERROR" != "" ]
		  then
				  atom_hang_count=`sysevent get atom_hang_count`
				  echo_t "[RDKB_SELFHEAL] : Atom is not responding. Count $atom_hang_count"
				  if [ $atom_hang_count -ge 2 ]; then
						  CheckRebootCretiriaForAtomHang
						  atom_hang_reboot_count=`syscfg get todays_atom_reboot_count`
						  if [ $atom_hang_reboot_count -eq 0 ]; then
							  echo_t "[RDKB_PLATFORM_ERROR] : Atom is not responding. Rebooting box.."
							  reason="ATOM_HANG"
							  rebootCount=1
							  #setRebootreason $reason $rebootCount
							  rebootNeeded $reason "" $reason $rebootCount
						  else
							  echo_t "[RDKB_SELFHEAL] : Reboot allowed for only one time per day. It will reboot in next 24hrs."
						  fi
				  else
						  atom_hang_count=$((atom_hang_count + 1))
						  sysevent set atom_hang_count $atom_hang_count
				  fi
		  else
				  sysevent set atom_hang_count 0
		  fi
	fi
###########################################

if [ "$MULTI_CORE" = "yes" ]; then
if [ -f $PING_PATH/ping_peer ]
then
## Check Peer ip is accessible
loop=1
	while [ "$loop" -le 3 ]
	do
        PING_RES=`ping_peer`
	CHECK_PING_RES=`echo $PING_RES | grep "packet loss" | cut -d"," -f3 | cut -d"%" -f1`

		if [ "$CHECK_PING_RES" != "" ]
		then
			if [ "$CHECK_PING_RES" -ne 100 ] 
			then
				ping_success=1
				echo_t "RDKB_SELFHEAL : Ping to Peer IP is success"
				break
			else
				ping_failed=1
			fi
		else
			ping_failed=1
		fi
		
		if [ "$ping_failed" -eq 1 ] && [ "$loop" -lt 3 ]
		then
			echo_t "RDKB_SELFHEAL : Ping to Peer IP failed in iteration $loop"
			echo "RDKB_SELFHEAL : Ping command output is $PING_RES"
		else
			echo_t "RDKB_SELFHEAL : Ping to Peer IP failed after iteration $loop also ,rebooting the device"
			echo "RDKB_SELFHEAL : Ping command output is $PING_RES"
			echo_t "RDKB_REBOOT : Peer is not up ,Rebooting device "
            		#echo_t " RDKB_SELFHEAL : Setting Last reboot reason as Peer_down"
            		reason="Peer_down"
          		rebootCount=1
         	    	#setRebootreason $reason $rebootCount
			rebootNeeded RM "" $reason $rebootCount

		fi
		loop=$((loop+1))
		sleep 5
	done
else
   echo_t "RDKB_SELFHEAL : ping_peer command not found"
fi

if [ -f $PING_PATH/arping_peer ]
then
    $PING_PATH/arping_peer
else
   echo_t "RDKB_SELFHEAL : arping_peer command not found"
fi
fi
########################################

	atomOnlyReboot=`dmesg -n 8 && dmesg | grep -i "Atom only"`
	if [ x$atomOnlyReboot = x ];then
		crTestop=`dmcli eRT getv com.cisco.spvtg.ccsp.CR.Name`
 		isCRAlive=`echo $crTestop | grep "Can't find destination compo"`
		if [ "$isCRAlive" != "" ]; then
			# Retest by querying some other parameter
			crReTestop=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.DeviceMode`
 			isCRAlive=`echo $crReTestop | grep "Can't find destination compo"`
		  	if [ "$isCRAlive" != "" ]; then
		#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : CR_process is not running, need to reboot the unit"
				echo_t "RDKB_PROCESS_CRASHED : CR_process is not running, need to reboot the unit"
				vendor=`getVendorName`
				modelName=`getModelName`
				CMMac=`getCMMac`
				timestamp=`getDate`
				#echo_t "Setting Last reboot reason"
				reason="CR_crash"
				rebootCount=1
				#setRebootreason $reason $rebootCount
				echo_t "SET succeeded"
				echo_t "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM CcspCrSsp process died,need reboot"
				touch $HAVECRASH
				rebootNeeded RM "CR" $reason $rebootCount
		 	fi		
		fi
	else
		echo_t "[RDKB_SELFHEAL] : Atom only reboot is triggered"
	fi

###########################################


	PAM_PID=`pidof CcspPandMSsp`
	if [ "$PAM_PID" = "" ]; then
		# Remove the P&M initialized flag
		rm -rf /tmp/pam_initialized
		echo_t "RDKB_PROCESS_CRASHED : PAM_process is not running, need restart"
		resetNeeded pam CcspPandMSsp
	fi
	
	# Checking MTA's PID
	MTA_PID=`pidof CcspMtaAgentSsp`
	if [ "$MTA_PID" = "" ]; then
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : MTA_process is not running, restarting it"
		echo_t "RDKB_PROCESS_CRASHED : MTA_process is not running, need restart"
		resetNeeded mta CcspMtaAgentSsp

	fi

	# Checking CM's PID
	CM_PID=`pidof CcspCMAgentSsp`
	if [ "$CM_PID" = "" ]; then
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : CM_process is not running, restarting it"
		echo_t "RDKB_PROCESS_CRASHED : CM_process is not running, need restart"
		resetNeeded cm CcspCMAgentSsp
	fi

	# Checking WEBController's PID
	WEBC_PID=`pidof CcspWecbController`
	if [ "$WEBC_PID" = "" ]; then
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : WECBController_process is not running, restarting it"
		echo_t "RDKB_PROCESS_CRASHED : WECBController_process is not running, need restart"
		resetNeeded wecb CcspWecbController
	fi

	# Checking RebootManager's PID
#	Rm_PID=`pidof CcspRmSsp`
#	if [ "$Rm_PID" = "" ]; then
	#	echo "[`getDateTime`] RDKB_PROCESS_CRASHED : RebootManager_process is not running, restarting it"
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : RebootManager_process is not running, need restart"
#		resetNeeded "rm" CcspRmSsp

#	fi

	# Checking TR69's PID
	TR69_PID=`pidof CcspTr069PaSsp`
	if [ "$TR69_PID" = "" ]; then
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : TR69_process is not running, need to reboot the unit"
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : TR69_process is not running, need to reboot the unit"
#		vendor=`getVendorName`
#		modelName=`getModelName`
#		CMMac=`getCMMac`
#		timestamp=`getDate`
#		echo "[`getDateTime`] Setting Last reboot reason"
#		dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string TR69_crash
#		echo "[`getDateTime`] SET succeeded"
#		echo "[`getDateTime`] RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM CcspTr069PaSsp process died,need reboot"

#		touch $HAVECRASH
#		rebootNeeded RM "TR69"
		echo_t "RDKB_PROCESS_CRASHED : TR69_process is not running, need restart"
		resetNeeded TR69 CcspTr069PaSsp
	fi

	# Checking Test adn Daignostic's PID
	TandD_PID=`pidof CcspTandDSsp`
	if [ "$TandD_PID" = "" ]; then
#		echo "[`getDateTime`] RDKB_PROCESS_CRASHED : TandD_process is not running, restarting it"
		echo_t "RDKB_PROCESS_CRASHED : TandD_process is not running, need restart"
		resetNeeded tad CcspTandDSsp
	fi

	# Checking Lan Manager PID
	LM_PID=`pidof CcspLMLite`
	if [ "$LM_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : LanManager_process is not running, need restart"
		resetNeeded lm CcspLMLite
	
	fi

	# Checking XdnsSsp PID
	XDNS_PID=`pidof CcspXdnsSsp`
	if [ "$XDNS_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : CcspXdnsSsp_process is not running, need restart"
		resetNeeded xdns CcspXdnsSsp

	fi

	# Checking snmp subagent PID
	SNMP_PID=`pidof snmp_subagent`
	if [ "$SNMP_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : snmp process is not running, need restart"
		resetNeeded snmp snmp_subagent 
	fi

	# Checking CcspMoCA PID
	MOCA_PID=`pidof CcspMoCA`
	if [ "$MOCA_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : CcspMoCA process is not running, need restart"
		resetNeeded moca CcspMoCA 
	fi

	HOMESEC_PID=`pidof CcspHomeSecurity`
	if [ "$HOMESEC_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : HomeSecurity process is not running, need restart"
		resetNeeded "" CcspHomeSecurity 
	fi

	HOTSPOT_ENABLE=`dmcli eRT getv Device.DeviceInfo.X_COMCAST_COM_xfinitywifiEnable | grep value | cut -f3 -d : | cut -f2 -d" "`
	if [ "$HOTSPOT_ENABLE" = "true" ]
	then
	
		DHCP_ARP_PID=`pidof hotspot_arpd`
		if [ "$DHCP_ARP_PID" = "" ] && [ -f /tmp/hotspot_arpd_up ]; then
		     echo_t "RDKB_PROCESS_CRASHED : DhcpArp_process is not running, need restart"
		     resetNeeded "" hotspot_arpd 
		fi

		#When Xfinitywifi is enabled, l2sd0.102 and l2sd0.103 should be present.
		#If they are not present below code shall re-create them
		#l2sd0.102 case 
		ifconfig -a | grep l2sd0.102
		if [ $? == 1 ]; then
		     echo_t "XfinityWifi is enabled, but l2sd0.102 interface is not created try creating it" 
		     sysevent set multinet_3-status stopped
		     $UTOPIA_PATH/service_multinet_exec multinet-start 3
		     ifconfig -a | grep l2sd0.102
		     if [ $? == 1 ]; then
		       echo "l2sd0.102 is not created at First Retry, try again after 2 sec"
		       sleep 2
		       sysevent set multinet_3-status stopped
		       $UTOPIA_PATH/service_multinet_exec multinet-start 3
		       ifconfig -a | grep l2sd0.102
		       if [ $? == 1 ]; then
		          echo "[RDKB_PLATFORM_ERROR] : l2sd0.102 is not created after Second Retry, no more retries !!!"
		       fi
		     else
		       echo "[RDKB_PLATFORM_ERROR] : l2sd0.102 created at First Retry itself"
		     fi
		else
		   echo "XfinityWifi is enabled and l2sd0.102 is present"  
		fi

		#l2sd0.103 case
		ifconfig -a | grep l2sd0.103
		if [ $? == 1 ]; then
		   echo_t "XfinityWifi is enabled, but l2sd0.103 interface is not created try creatig it" 
		   sysevent set multinet_4-status stopped
		   $UTOPIA_PATH/service_multinet_exec multinet-start 4
		   ifconfig -a | grep l2sd0.103
		   if [ $? == 1 ]; then
		      echo "l2sd0.103 is not created at First Retry, try again after 2 sec"
		      sleep 2
		      sysevent set multinet_4-status stopped
		      $UTOPIA_PATH/service_multinet_exec multinet-start 4
		      ifconfig -a | grep l2sd0.103
		      if [ $? == 1 ]; then
		         echo "[RDKB_PLATFORM_ERROR] : l2sd0.103 is not created after Second Retry, no more retries !!!"
		      fi
		   else
		        echo "[RDKB_PLATFORM_ERROR] : l2sd0.103 created at First Retry itself"
		   fi
		else
		   echo "Xfinitywifi is enabled and l2sd0.103 is present"
		fi
	fi
if [ -f "/etc/PARODUS_ENABLE" ]; then
	# Checking parodus PID
        PARODUS_PID=`pidof parodus`
        if [ "$PARODUS_PID" = "" ]; then
            processCount=`ps -elf |grep parodus_start.sh|wc -l`
	    echo "processCount for parodus script is $processCount"
	    if [ "$processCount" -gt "1" ]; then
	        echo "parodus_start script is already running, parodus is yet to start"
            else 	
                echo_t "RDKB_PROCESS_CRASHED : parodus process is not running, need restart"
                echo_t "Starting parodus in background "
                cd /usr/ccsp/parodus
                sh  ./parodus_start.sh &
                echo_t "Started parodus_start script"
                cd -
            fi
        fi
else
	# Checking webpa PID
	WEBPA_PID=`pidof webpa`
	if [ "$WEBPA_PID" = "" ]; then
		ENABLEWEBPA=`cat /nvram/webpa_cfg.json | grep -r EnablePa | awk '{print $2}' | sed 's|[\"\",]||g'`
		if [ "$ENABLEWEBPA" = "true" ];then
		echo_t "RDKB_PROCESS_CRASHED : WebPA_process is not running, need restart"
			#We'll set the reason only if webpa reconnect is not due to DNS resolve
			syscfg get X_RDKCENTRAL-COM_LastReconnectReason | grep "Dns_Res_webpa_reconnect"
			if [ $? != 0 ]; then
				echo "setting reconnect reason from task_health_monitor.sh"
			echo_t "Setting Last reconnect reason"
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
			echo_t "SET succeeded"
		fi
			resetNeeded webpa webpa
		fi
	
	fi
fi
	#Check if we support rsync dropbear 
	if [ "$ARM_INTERFACE_IP" == "" ]
	then
	    DROPBEAR_PID=`pidof dropbear`
	else
	    DROPBEAR_PID=`ps | grep dropbear | grep -v "$ARM_INTERFACE_IP" | grep -v grep`
	fi

	dropbear_flagged=0
	if [ "$DROPBEAR_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : dropbear_process is not running, restarting it"
		dropbear_flagged=1
		sh /etc/utopia/service.d/service_sshd.sh sshd-restart &
		sleep 3
	fi

	#Check dropbear is alive to do rsync/scp to/fro ATOM
	if [ "$ARM_INTERFACE_IP" != "" ]
	then
           DROPBEAR_ENABLE=`ps | grep dropbear | grep $ARM_INTERFACE_IP`
           if [ "$DROPBEAR_ENABLE" == "" ]
           then
               # No need to print this message as we have already printed the log message
               if [ $dropbear_flagged -eq 0 ]
               then
                  dropbear_flagged=0
                  echo_t "RDKB_PROCESS_CRASHED : rsync_dropbear_process is not running, need restart"
               fi
               dropbear -E -B -p $ARM_INTERFACE_IP:22 -P /var/run/dropbear_ipc.pid > /dev/null 2>&1
           fi
        fi

	# Checking lighttpd PID
	LIGHTTPD_PID=`pidof lighttpd`
	if [ "$LIGHTTPD_PID" = "" ]; then
		isPortKilled=`netstat -anp | grep 51515`
		if [ "$isPortKilled" != "" ]
		then
		    echo_t "Port 51515 is still alive. Killing processes associated to 51515"
		    fuser -k 51515/tcp
		fi
		echo_t "RDKB_PROCESS_CRASHED : lighttpd is not running, restarting it"
		#lighttpd -f $LIGHTTPD_CONF
		sh /etc/webgui.sh
	fi
	
# Checking syseventd PID
 	SYSEVENT_PID=`pidof syseventd`
	if [ "$SYSEVENT_PID" == "" ]
	then
		if [ ! -f "$SyseventdCrashed"  ]
		then
			echo_t "[RDKB_PROCESS_CRASHED] : syseventd is crashed, need to reboot the device in maintanance window." 
			touch $SyseventdCrashed
		fi
		rebootDeviceNeeded=1


	fi

        # Verify MDC is enabled in the build by
        # checking if /usr/bin/Arm_Mdc exists
        ArmMdc_PID=`pidof Arm_Mdc`
	if [ -e /usr/bin/Arm_Mdc ] && [ "$ArmMdc_PID" = "" ]; then
		echo "RDKB_PROCESS_CRASHED : Arm_Mdc is not running, restarting it"
		resetNeeded CcspArmMdc Arm_Mdc
	fi


# Checking whether brlan0 and l2sd0.100 are created properly , if not recreate it
	lanSelfheal=`sysevent get lan_selfheal`
	echo_t "[RDKB_SELFHEAL] : Value of lanSelfheal : $lanSelfheal"
	if [ "$lanSelfheal" != "done" ]
	then

        	check_device_mode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
        	check_param_get_succeed=`echo $check_device_mode | grep "Execution succeed"`
        	if [ "$check_param_get_succeed" != "" ]
        	then
			check_device_in_router_mode=`echo $check_param_get_succeed | grep router`
			if [ "$check_device_in_router_mode" != "" ]
			then
				check_if_brlan0_created=`ifconfig | grep brlan0`
				check_if_brlan0_up=`ifconfig brlan0 | grep UP`
				check_if_brlan0_hasip=`ifconfig brlan0 | grep "inet addr"`
				check_if_l2sd0_100_created=`ifconfig | grep l2sd0.100`
				check_if_l2sd0_100_up=`ifconfig l2sd0.100 | grep UP `
				if [ "$check_if_brlan0_created" = "" ] || [ "$check_if_brlan0_up" = "" ] || [ "$check_if_brlan0_hasip" = "" ] || [ "$check_if_l2sd0_100_created" = "" ] || [ "$check_if_l2sd0_100_up" = "" ]
				then
					echo_t "[RDKB_PLATFORM_ERROR] : Either brlan0 or l2sd0.100 is not completely up, setting event to recreate vlan and brlan0 interface"
					logNetworkInfo

					ipv4_status=`sysevent get ipv4_4-status`
					lan_status=`sysevent get lan-status`

					if [ "$ipv4_status" = "" ] && [ "$lan_status" != "started" ]
					then
						echo_t "[RDKB_SELFHEAL] : ipv4_4-status is not set or lan is not started, setting lan-start event"
						sysevent set lan-start
						sleep 5
					fi

					sysevent set multinet-down 1
					sleep 5
					sysevent set multinet-up 1
					sleep 30
					sysevent set lan_selfheal done
				fi

            		fi
        	else
            		echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while fetching device mode "
        	fi
	else
		echo_t "[RDKB_SELFHEAL] : brlan0 already restarted. Not restarting again"
	fi


# Checking whether brlan1 and l2sd0.101 interface are created properly

	l3netRestart=`sysevent get l3net_selfheal`
	echo_t "[RDKB_SELFHEAL] : Value of l3net_selfheal : $l3netRestart"

	if [ "$l3netRestart" != "done" ]
	then

		check_if_brlan1_created=`ifconfig | grep brlan1`
		check_if_brlan1_up=`ifconfig brlan1 | grep UP`
        	check_if_brlan1_hasip=`ifconfig brlan1 | grep "inet addr"`
		check_if_l2sd0_101_created=`ifconfig | grep l2sd0.101`
		check_if_l2sd0_101_up=`ifconfig l2sd0.101 | grep UP `
	
		if [ "$check_if_brlan1_created" = "" ] || [ "$check_if_brlan1_up" = "" ] || [ "$check_if_brlan1_hasip" = "" ] || [ "$check_if_l2sd0_101_created" = "" ] || [ "$check_if_l2sd0_101_up" = "" ]
        	then
	       		echo_t "[RDKB_PLATFORM_ERROR] : Either brlan1 or l2sd0.101 is not completely up, setting event to recreate vlan and brlan1 interface"

			ipv5_status=`sysevent get ipv4_5-status`
	        	lan_l3net=`sysevent get homesecurity_lan_l3net`

			if [ "$ipv5_status" = "" ] && [ "$lan_l3net" != "" ]
			then
				echo_t "[RDKB_SELFHEAL] : ipv5_4-status is not set , setting event to create homesecurity lan"
				sysevent set ipv4-up $lan_l3net
				sleep 5
			fi

			sysevent set multinet-down 2
			sleep 5
			sysevent set multinet-up 2
			sleep 10
			sysevent set l3net_selfheal done
		fi
	else
		echo_t "[RDKB_SELFHEAL] : brlan1 already restarted. Not restarting again"
	fi



        SSID_DISABLED=0
        BR_MODE=0
        ssidEnable=`dmcli eRT getv Device.WiFi.SSID.2.Enable`
        ssidExecution=`echo $ssidEnable | grep "Execution succeed"`
        if [ "$ssidExecution" != "" ]
        then
           isEnabled=`echo $ssidEnable | grep "false"`
           if [ "$isEnabled" != "" ]
           then
             SSID_DISABLED=1
             echo_t "[RDKB_SELFHEAL] : SSID 5GHZ is disabled"
           fi
        else
           destinationError=`echo $ssidEnable | grep "Can't find destination component"`
           if [ "$destinationError" != "" ]
           then
                echo_t "[RDKB_PLATFORM_ERROR] : Parameter cannot be found on WiFi subsystem"
           else
                echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Enable"            
           fi
        fi

        bridgeMode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
        # RDKB-6895
        bridgeSucceed=`echo $bridgeMode | grep "Execution succeed"`
        if [ "$bridgeSucceed" != "" ]
        then
           isBridging=`echo $bridgeMode | grep router`
           if [ "$isBridging" = "" ]
           then
               BR_MODE=1
               echo_t "[RDKB_SELFHEAL] : Device in bridge mode"
           fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking bridge mode."

	    pandm_timeout=`echo $bridgeMode | grep "CCSP_ERR_TIMEOUT"`
	    pandm_notexist=`echo $bridgeMode | grep "CCSP_ERR_NOT_EXIST"`
	    if [ "$pandm_timeout" != "" ] || [ "$pandm_notexist" != "" ]
	    then
		echo_t "[RDKB_PLATFORM_ERROR] : pandm parameter timed out or failed to return"
		cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.pam.Name`
		cr_timeout=`echo $cr_query | grep "CCSP_ERR_TIMEOUT"`
		cr_pam_notexist=`echo $cr_query | grep "CCSP_ERR_NOT_EXIST"`
		if [ "$cr_timeout" != "" ] || [ "$cr_pam_notexist" != "" ]
		then
			echo_t "[RDKB_PLATFORM_ERROR] : pandm process is not responding. Restarting it"
			PANDM_PID=`pidof CcspPandMSsp`
			if [ "$PANDM_PID" != "" ]; then
				kill -9 $PANDM_PID
			fi
			rm -rf /tmp/pam_initialized
			resetNeeded pam CcspPandMSsp
		fi
	    fi

        fi

        # If bridge mode is not set and WiFI is not disabled by user,
        # check the status of SSID
        if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED -eq 0 ]
        then           
	    ssidStatus_5=`dmcli eRT getv Device.WiFi.SSID.2.Status`
            isExecutionSucceed=`echo $ssidStatus_5 | grep "Execution succeed"`
            if [ "$isExecutionSucceed" != "" ]
            then       
        
	            isUp=`echo $ssidStatus_5 | grep "Up"`
                if [ "$isUp" = "" ]
                then
                   # We need to verify if it was a dmcli crash or is WiFi really down
		           isDown=`echo $ssidStatus_5 | grep "Down"`
		           if [ "$isDown" != "" ]; then
                      echo_t "[RDKB_PLATFORM_ERROR] : 5G private SSID (ath1) is off."
                   else
                      echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G status."                      
                   fi
                fi
            else
               echo_t "[RDKB_PLATFORM_ERROR] : dmcli crashed or something went wrong while checking 5G status."
            fi
        fi

        # Check the status if 2.4GHz Wifi SSID
        SSID_DISABLED_2G=0
        ssidEnable_2=`dmcli eRT getv Device.WiFi.SSID.1.Enable`
        ssidExecution_2=`echo $ssidEnable_2 | grep "Execution succeed"`

        if [ "$ssidExecution_2" != "" ]
        then
            isEnabled_2=`echo $ssidEnable_2 | grep "false"`
            if [ "$isEnabled_2" != "" ]
            then
               SSID_DISABLED_2G=1
               echo_t "[RDKB_SELFHEAL] : SSID 2.4GHZ is disabled"
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G Enable"            
        fi

        # If bridge mode is not set and WiFI is not disabled by user,
        # check the status of SSID
        if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED_2G -eq 0 ]
        then
	        ssidStatus_2=`dmcli eRT getv Device.WiFi.SSID.1.Status`
            isExecutionSucceed_2=`echo $ssidStatus_2 | grep "Execution succeed"`
            if [ "$isExecutionSucceed_2" != "" ]
            then       
        
	            isUp=`echo $ssidStatus_2 | grep "Up"`
                if [ "$isUp" = "" ]
                then
                    # We need to verify if it was a dmcli crash or is WiFi really down
		            isDown=`echo $ssidStatus_2 | grep "Down"`
		            if [ "$isDown" != "" ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : 2.4G private SSID (ath0) is off."
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G status."                      
                    fi
                fi
            else
               echo_t "[RDKB_PLATFORM_ERROR] : dmcli crashed or something went wrong while checking 2.4G status."
            fi
        fi
        
	FIREWALL_ENABLED=`syscfg get firewall_enabled`

	echo_t "[RDKB_SELFHEAL] : BRIDGE_MODE is $BR_MODE"
    echo_t "[RDKB_SELFHEAL] : FIREWALL_ENABLED is $FIREWALL_ENABLED"

	if [ $BR_MODE -eq 0 ] 
	then
		iptables-save -t nat | grep "A PREROUTING -i"
		if [ $? == 1 ]; then
		echo_t "[RDKB_PLATFORM_ERROR] : iptable corrupted."
		#sysevent set firewall-restart
		fi
     fi

#Checking whether dnsmasq is running or not
   DNS_PID=`pidof dnsmasq`
   if [ "$DNS_PID" == "" ]
   then
		 echo_t "[RDKB_SELFHEAL] : dnsmasq is is not running"   
   else
	     brlan1up=`cat /var/dnsmasq.conf | grep brlan1`
	     brlan0up=`cat /var/dnsmasq.conf | grep brlan0`
             infup=`cat /var/dnsmasq.conf | grep l2sd0.106`

	     IsAnyOneInfFailtoUp=0	

	     if [ $BR_MODE -eq 0 ]
	     then
			if [ "$brlan0up" == "" ]
			then
			    echo_t "[RDKB_SELFHEAL] : brlan0 info is not availble in dnsmasq.conf"
			    IsAnyOneInfFailtoUp=1
			fi
	     fi

	     if [ "$brlan1up" == "" ]
	     then
	         echo_t "[RDKB_SELFHEAL] : brlan1 info is not availble in dnsmasq.conf"
			 IsAnyOneInfFailtoUp=1
	     fi

             if [ "$infup" == "" ]
             then
                 echo_t "[RDKB_SELFHEAL] : l2sd0.106 info is not availble in dnsmasq.conf"
			 IsAnyOneInfFailtoUp=1
             fi

	     if [ ! -f /tmp/dnsmasq_restarted_via_selfheal ] 
	     then
		     if [ $IsAnyOneInfFailtoUp -eq 1 ]
		     then
				 touch /tmp/dnsmasq_restarted_via_selfheal

		         echo_t "[RDKB_SELFHEAL] : dnsmasq.conf is."   
			 	 echo "`cat /var/dnsmasq.conf`"

				 echo_t "[RDKB_SELFHEAL] : Setting an event to restart dnsmasq"
		         sysevent set dhcp_server-stop
		         sysevent set dhcp_server-start
		     fi
	     fi
	
	checkIfDnsmasqIsZombie=`ps | grep dnsmasq | grep "Z" | awk '{ print $1 }'`
	if [ "$checkIfDnsmasqIsZombie" != "" ] ; then
		confirmZombie=`grep "State:" /proc/$checkIfDnsmasqIsZombie/status | grep -i "zombie"`
		if [ "$confirmZombie" != "" ] ; then
			echo_t "[RDKB_SELFHEAL] : Zombie instance of dnsmasq is present, restarting dnsmasq"
			kill -9 `pidof dnsmasq`
			sysevent set dhcp_server-stop
			sysevent set dhcp_server-start
		fi
	fi

   fi

#Checking dibbler server is running or not RDKB_10683
	DIBBLER_PID=`pidof dibbler-server`
	if [ "$DIBBLER_PID" = "" ]; then

		DHCPV6C_ENABLED=`sysevent get dhcpv6c_enabled`
		if [ "$BR_MODE" == "0" ] && [ "$DHCPV6C_ENABLED" == "1" ]; then

			echo "[`getDateTime`] RDKB_PROCESS_CRASHED : Dibbler is not running, restarting the dibbler"
			if [ -f "/etc/dibbler/server.conf" ]
			then
				dibbler-server stop
				sleep 2
				dibbler-server start
			else
				echo "[`getDateTime`] RDKB_PROCESS_CRASHED : Server.conf file not present, Cannot restart dibbler"
			fi
		fi
	fi

#Checking the zebra is running or not
	ZEBRA_PID=`pidof zebra`
	if [ "$ZEBRA_PID" = "" ]; then
		if [ "$BR_MODE" == "0" ]; then

			echo "[`getDateTime`] RDKB_PROCESS_CRASHED : zebra is not running, restarting the zebra"
			sysevent set zebra-restart
		fi
	fi

#Checking the ntpd is running or not
	NTPD_PID=`pidof ntpd`
	if [ "$NTPD_PID" = "" ]; then
			echo "[`getDateTime`] RDKB_PROCESS_CRASHED : NTPD is not running, restarting the NTPD"
			sysevent set ntpd-restart
	fi

# Checking for WAN_INTERFACE ipv6 address
DHCPV6_ERROR_FILE="/tmp/.dhcpv6SolicitLoopError"
WAN_STATUS=`sysevent get wan-status`
WAN_IPv4_Addr=`ifconfig $WAN_INTERFACE | grep inet | grep -v inet6`
DHCPV6_HANDLER="/etc/utopia/service.d/service_dhcpv6_client.sh"

if [ -f "$DHCPV6_ERROR_FILE" ] && [ "$WAN_STATUS" = "started" ] && [ "$WAN_IPv4_Addr" != "" ]
then
	          isIPv6=`ifconfig $WAN_INTERFACE | grep inet6 | grep "Scope:Global"`
		echo "isIPv6 = $isIPv6"
        	 if [ "$isIPv6" == "" ]
		 then
			echo_t "[RDKB_SELFHEAL] : $DHCPV6_ERROR_FILE file present and $WAN_INTERFACE ipv6 address is empty, restarting ti_dhcp6c"
			rm -rf $DHCPV6_ERROR_FILE
			sh $DHCPV6_HANDLER disable
			sleep 2
			sh $DHCPV6_HANDLER enable
           	fi 
fi

if [ "$WAN_STATUS" = "started" ];then
	wan_dhcp_client_v4=1
	wan_dhcp_client_v6=1
	dhcp_cli_output=`ps w | grep ti_ | grep erouter0`

	check_wan_dhcp_client_v4=`echo $dhcp_cli_output | grep ti_udhcpc`
	check_wan_dhcp_client_v6=`echo $dhcp_cli_output | grep ti_dhcp6c`

	if [ "x$check_wan_dhcp_client_v4" = "x" ]; then
		echo "RDKB_PROCESS_CRASHED : DHCP Client for v4 is not running, need restart "
		wan_dhcp_client_v4=0
	fi

	if [ "x$check_wan_dhcp_client_v6" = "x" ]; then
		echo "RDKB_PROCESS_CRASHED : DHCP Client for v6 is not running, need restart"
		wan_dhcp_client_v6=0
	fi

	DHCP_STATUS=`dmcli eRT getv Device.DHCPv4.Client.1.DHCPStatus | grep value | cut -f3 -d : | cut -f2 -d" "`

	if [ "$DHCP_STATUS" = "Rebinding" ] ; then
		if [ $wan_dhcp_client_v4 -eq 0 ] || [ $wan_dhcp_client_v6 -eq 0 ]; then
			echo "DHCP_CLIENT : DHCPStatus is rebinding, restarting WAN"
			sh /etc/utopia/service.d/service_wan.sh wan-stop
			sh /etc/utopia/service.d/service_wan.sh wan-start
			wan_dhcp_client_v4=1
			wan_dhcp_client_v6=1
		fi
	fi

	if [ $wan_dhcp_client_v4 -eq 0 ];
	then
		DHCPC_PID_FILE="/var/run/eRT_ti_udhcpc.pid"
		echo "DHCP_CLIENT : Restarting DHCP Client for v4"
		ti_udhcpc -plugin /lib/libert_dhcpv4_plugin.so -i $WAN_INTERFACE -H DocsisGateway -p $DHCPC_PID_FILE -B -b 1
		sleep 5
		wan_dhcp_client_v4=1
	fi

	if [ $wan_dhcp_client_v6 -eq 0 ];
	then
		echo "DHCP_CLIENT : Restarting DHCP Client for v6"
		sh $DHCPV6_HANDLER disable
		sleep 2
		sh $DHCPV6_HANDLER enable
		wan_dhcp_client_v6=1
	fi

fi

	if [ "$rebootDeviceNeeded" -eq 1 ]
	then

		if [ "$UTC_ENABLE" == "true" ]
		then
			cur_hr=`LTime H`
			cur_min=`LTime M`
		else
			cur_hr=`date +"%H"`
			cur_min=`date +"%M"`
		fi

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
						echo_t "RDKB_REBOOT : brlan1 interface is not up, rebooting the device."
						echo_t "Setting Last reboot reason"
						dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string brlan1_down
						echo_t "SET succeeded"
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
