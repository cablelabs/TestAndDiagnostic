#!/bin/sh

source /fss/gw/etc/utopia/service.d/log_env_var.sh
CM_INTERFACE=wan0

exec 3>&1 4>&2 >>$SELFHEALFILE 2>&1

voiceCallCompleted=0
xhsTraffic=0
CMRegComplete=0

level=128

DELAY=1

getstat() {
    grep 'cpu ' /proc/stat | sed -e 's/  */x/g' -e 's/^cpux//'
}

extract() {
    echo $1 | cut -d 'x' -f $2
}

change() {
    local e=$(extract $ENDSTAT $1)
    local b=$(extract $STARTSTAT $1)
    local diff=$(( $e - $b ))
    echo $diff
}

getVendorName()
{
	vendorName=`dmcli eRT getv Device.DeviceInfo.Manufacturer | grep value | awk '{print $5}'`
	echo "$vendorName"
}

getModelName()
{
	modelName=`dmcli eRT getv Device.DeviceInfo.ModelName | grep value | awk '{print $5}'`
	echo "$modelName"
}

getDate()
{
	dandt_now=`date +'%Y:%m:%d:%H:%M:%S'`
	echo "$dandt_now"
}

getCMMac()
{
	CMMac=`dmcli eRT getv Device.X_CISCO_COM_CableModem.MACAddress | grep value | awk '{print $5}'`
	echo "$CMMac"
}

checkConditionsbeforeAction()
{

	 isIPv4=`ifconfig $CM_INTERFACE | grep inet | grep -v inet6`
	 if [ "$isIPv4" = "" ]
	 then
        	 isIPv6=`ifconfig $CM_INTERFACE | grep inet6 | grep "Scope:Global"`
        	 if [ "$isIPv6" != "" ]
		 then
			CMRegComplete=1
		 else
		   	CMRegComplete=0
			echo "RDKB_SELFHEAL : eCM is not fully registered on its CMTS,returning failure"
			return 1			
		 fi
	 else
		CMRegComplete=1
	 fi
			

	printOnce=1
	while : ; do

		#xhs traffic implementation pending 
		xhsTraffic=1		
		/usr/bin/XconfHttpDl http_reboot_status
		voicecall_status=$?
		if [ "$voicecall_status" -eq 0 ]
		then
			echo "RDKB_SELFHEAL : No active voice call traffic currently"
			voiceCallCompleted=1
		else
			if [ "$printOnce" -eq 1 ]
			then
				echo "RDKB_SELFHEAL : Currently there is active call, wait for active call to finish"
				voiceCallCompleted=0
				printOnce=0
			fi
		
		fi

		if [ "$voiceCallCompleted" -eq 1 ] && [ "$xhsTraffic" -eq 1 ]
		then
			return 0
		fi

		sleep 2
	done

}

rebootNeeded()
{


	# Check for max subsystem reboot
	# Implement as a indipendent script which can be accessed across both connectivity and resource scripts
	storedTime=`syscfg get lastActiontakentime`


	if [ "$storedTime" != "" ] || [ "$storedTime" -ne 0 ]
	then
		currTime=$(date -u +"%s")
		diff=$(($currTime-$storedTime))
		diff_in_minutes=$(($diff / 60))
		diff_in_hours=$(($diff_in_minutes / 60))
		if [ "$diff_in_hours" -ge 24 ]
		then

			sh /fss/gw/usr/ccsp/tad/selfheal_reset_counts.sh

		fi
		
	fi

	MAX_REBOOT_COUNT=`syscfg get max_reboot_count`
	TODAYS_REBOOT_COUNT=`syscfg get todays_reboot_count`

	if [ "$TODAYS_REBOOT_COUNT" -ge "$MAX_REBOOT_COUNT" ]
	then
		echo "RDKB_SELFHEAL : Today's max reboot count already reached, please wait for reboot till next 24 hour window"
	else

		# Wait for Active Voice call,XHS client passing traffic,eCM registrations state completion.
		checkConditionsbeforeAction

		return_value=$?

		if [ "$return_value" -eq 0 ]
		then
			# Storing Information before corrective action
			storeInformation
			if [ "$1" == "PING" ]
			then
				echo "RDKB_SELFHEAL : DNS Information :"
				cat /etc/resolv.conf
				echo "-------------------------------------------------------"
				echo "RDKB_SELFHEAL : IPtable rules:"
				iptables -S
				echo "-------------------------------------------------------"
				echo "RDKB_SELFHEAL : Ipv4 Route Information:"
				ip route
				echo "-------------------------------------------------------"
				echo "RDKB_SELFHEAL : IProute Information:"
				route
				echo "-------------------------------------------------------"
	
				echo "-------------------------------------------------------"
				echo "RDKB_SELFHEAL : IP6table rules:"
				ip6tables -S
				echo "-------------------------------------------------------"
				echo "RDKB_SELFHEAL : Ipv6 Route Information:"
				ip -6 route
				echo "-------------------------------------------------------"
			
				echo "RDKB_REBOOT : Rebooting due to PING connectivity test failure"
			fi

			#touch $REBOOTNEEDED
			TODAYS_REBOOT_COUNT=$(($TODAYS_REBOOT_COUNT+1))
			syscfg set todays_reboot_count $TODAYS_REBOOT_COUNT
			syscfg commit
			vendor=`getVendorName`
			modelName=`getModelName`
			CMMac=`getCMMac`
			timestamp=`getDate`


			echo "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000000><$timestamp><$CMMac><$modelName> $1 Rebooting device as part of corrective action"

			if [ "$storedTime" == "" ] || [ "$storedTime" -eq 0 ]
			then
				storedTime=$(date -u +"%s")
				syscfg set lastActiontakentime $storedTime
				syscfg commit
			fi
			if [ "$2" == "CPU" ] || [ "$2" == "MEM" ]
			then
				echo "RDKB_REBOOT : Rebooting device due to $2 threshold reached"	
			fi
			/fss/gw/rdklogger/backupLogs.sh "true" "$2"
		fi	
	fi

}

# This function will check if captive portal needs to be enabled or not.
checkCaptivePortal()
{

# Get all flags from DBs
isWiFiConfigured=`syscfg get redirection_flag`
psmNotificationCP=`psmcli get eRT.com.cisco.spvtg.ccsp.Device.WiFi.NotifyWiFiChanges`

#Read the http response value
networkResponse=`cat /var/tmp/networkresponse.txt`

iter=0
max_iter=2
while [ "$psmNotificationCP" = "" ] && [ "$iter" -le $max_iter ]
do
	iter=$((iter+1))
	echo "$iter"
	psmNotificationCP=`psmcli get eRT.com.cisco.spvtg.ccsp.Device.WiFi.NotifyWiFiChanges`
done

echo "RDKB_SELFHEAL : NotifyWiFiChanges is $psmNotificationCP"
echo "RDKB_SELFHEAL : redirection_flag val is $isWiFiConfigured"

if [ "$isWiFiConfigured" = "true" ]
then
	if [ "$networkResponse" = "204" ] && [ "$psmNotificationCP" = "true" ]
	then
		# Check if P&M is up and able to find the captive portal parameter
		while : ; do
			echo "RDKB_SELFHEAL : Waiting for PandM to initalize completely to set ConfigureWiFi flag"
			CHECK_PAM_INITIALIZED=`find /tmp/ -name "pam_initialized"`
			echo "RDKB_SELFHEAL : CHECK_PAM_INITIALIZED is $CHECK_PAM_INITIALIZED"
			if [ "$CHECK_PAM_INITIALIZED" != "" ]
			then
				echo "RDKB_SELFHEAL : WiFi is not configured, setting ConfigureWiFi to true"
				output=`dmcli eRT setvalues Device.DeviceInfo.X_RDKCENTRAL-COM_ConfigureWiFi bool TRUE`
				check_success=`echo $output | grep  "Execution succeed."`
				if [ "$check_success" != "" ]
				then
					echo "RDKB_SELFHEAL : Setting ConfigureWiFi to true is success"
				fi
				break
			fi
			sleep 2
		done
	else
		echo "RDKB_SELFHEAL : We have not received a 204 response or PSM valus is not in sync"
	fi
else
	echo "RDKB_SELFHEAL : Syscfg DB value is : $isWiFiConfigured"
fi	

}

resetNeeded()
{
	folderName=$1
	ProcessName=$2
	
	BASEQUEUE=1
	keepalive_args="-n `sysevent get wan_ifname` -e 1"

	export LD_LIBRARY_PATH=$PWD:.:$PWD/../../lib:$PWD/../../.:/lib:/usr/lib:$LD_LIBRARY_PATH
	export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket

	BINPATH="/usr/bin"

	if [ -f /tmp/cp_subsys_ert ]; then
        	Subsys="eRT."
	elif [ -e ./cp_subsys_emg ]; then
        	Subsys="eMG."
	else
        	Subsys=""
	fi

	storedTime=`syscfg get lastActiontakentime`

	if [ "$storedTime" != "" ] || [ "$storedTime" -ne 0 ]
	then
		currTime=$(date -u +"%s")
		diff=$(($currTime-$storedTime))
		diff_in_minutes=$(($diff / 60))
		diff_in_hours=$(($diff_in_minutes / 60))

		if [ "$diff_in_hours" -ge 24 ]
		then
			sh /fss/gw/usr/ccsp/tad/selfheal_reset_counts.sh

		fi
		
	fi

	MAX_RESET_COUNT=`syscfg get max_reset_count`
	TODAYS_RESET_COUNT=`syscfg get todays_reset_count`

	if [ "$TODAYS_RESET_COUNT" -ge "$MAX_RESET_COUNT" ]
	then
		echo "RDKB_SELFHEAL : Today's max reset count already reached, please wait for reset till next 24 hour window"
	else
		#touch $RESETNEEDED

		checkConditionsbeforeAction
		return_value=$?

		if [ "$return_value" -eq 0 ]
		then

			# Storing Information before corrective action
		 	storeInformation

			TODAYS_RESET_COUNT=$(($TODAYS_RESET_COUNT+1))

			syscfg set todays_reset_count $TODAYS_RESET_COUNT
			syscfg commit
			vendor=`getVendorName`
			modelName=`getModelName`
			CMMac=`getCMMac`
			timestamp=`getDate`

			echo "RDKB_SELFHEAL : <$level>CABLEMODEM[$vendor]:<99000007><$timestamp><$CMMac><$modelName> RM $ProcessName process not running , restarting it"


			if [ "$storedTime" == "" ] || [ "$storedTime" -eq 0 ]
			then
				storedTime=$(date -u +"%s")
				syscfg set lastActiontakentime $storedTime
				syscfg commit
			fi

			if [ "$ProcessName" == "snmp_subagent" ]
			then
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
				cd /fss/gw/usr/ccsp/snmp/
				sh run_subagent.sh /var/tmp/cm_snmp_ma &
				cd -	
			elif [ "$ProcessName" == "CcspPandMSsp" ]
			then
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
				cd /usr/ccsp/pam/
				$BINPATH/CcspPandMSsp -subsys $Subsys
				cd -
				# We need to check whether to enable captive portal flag
				checkCaptivePortal
			elif [ "$ProcessName" == "CcspHomeSecurity" ]
			then
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
				CcspHomeSecurity 8081&

			elif [ "$ProcessName" == "hotspotfd" ]
			then
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
	        		hotspotfd $keepalive_args  > /dev/null &

			elif [ "$ProcessName" == "dhcp_snooperd" ]
			then
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
	        		dhcp_snooperd -q $BASEQUEUE -n 2 -e 1  > /dev/null &

			elif [ "$ProcessName" == "hotspot_arpd" ]
			then
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
        			hotspot_arpd -q 0  > /dev/null &

			elif [ "$3" == "noSubsys" ]
			then 
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
				cd $BINPATH
				./$ProcessName &
				cd -

			else
				echo "RDKB_SELFHEAL : Resetting process $ProcessName"
				cd $BINPATH
				./$ProcessName -subsys $Subsys
				cd -
			fi
		fi
			
	fi


}


storeInformation()
{

	totalMemSys=`free | awk 'FNR == 2 {print $2}'`
	usedMemSys=`free | awk 'FNR == 2 {print $3}'`
	freeMemSys=`free | awk 'FNR == 2 {print $4}'`

	# AvgCpuUsed=`grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}'`

#	echo "RDKB_SYS_MEM_INFO_SYS : Total memory in system is $totalMemSys"
#	echo "RDKB_SYS_MEM_INFO_SYS : Used memory in system is $usedMemSys"
#	echo "RDKB_SYS_MEM_INFO_SYS : Free memory in system is $freeMemSys"

	echo "RDKB_SELFHEAL : Total memory in system is $totalMemSys"
	echo "RDKB_SELFHEAL : Used memory in system is $usedMemSys"
	echo "RDKB_SELFHEAL : Free memory in system is $freeMemSys"

	#Record the start statistics
	STARTSTAT=$(getstat)

	sleep $DELAY

	#Record the end statistics
	ENDSTAT=$(getstat)

	USR=$(change 1)
	SYS=$(change 3)
	IDLE=$(change 4)
	IOW=$(change 5)


	ACTIVE=$(( $USR + $SYS + $IOW ))

	TOTAL=$(($ACTIVE + $IDLE))

	Curr_CPULoad=$(( $ACTIVE * 100 / $TOTAL ))

	echo "RDKB_SELFHEAL : Current CPU load is $Curr_CPULoad"

	echo "RDKB_SELFHEAL : Top 5 tasks running on device with resource usage are below"
	top -bn1 | head -n10 | tail -6

	for index in 1 2 3 5 6
	do

	   numberOfEntries=`dmcli eRT getv Device.WiFi.AccessPoint.$index.AssociatedDeviceNumberOfEntries | grep value | awk '{print $5}'`

		if [ "$numberOfEntries" -ne 0 ]
		then
			assocDev=1
			while [ "$assocDev" -le "$numberOfEntries" ]
			do
				MACADDRESS=`dmcli eRT getv Device.WiFi.AccessPoint.$index.AssociatedDevice.$assocDev.MACAddress | grep value | awk '{print $5}'`
				RSSI=`dmcli eRT getv Device.WiFi.AccessPoint.$index.AssociatedDevice.$assocDev.SignalStrength | grep value | awk '{print $5}'`	
				echo "RDKB_SELFHEAL : Device $MACADDRESS connected on AccessPoint $index and RSSI is $RSSI dBm"
				assocDev=$(($assocDev+1))
			done
		fi
	done

	for radio_index in 1 2 
	do
		channel=`dmcli eRT getv Device.WiFi.Radio.$radio_index.Channel | grep value | awk '{print $5}'`		
		if [ "$radio_index" -eq 1 ]
		then
			echo "RDKB_SELFHEAL : 2.4GHz radio is operating on $channel channel"
		else
			echo "RDKB_SELFHEAL : 5GHz radio is operating on $channel channel"
		fi
	done

	# Need to capture MoCA stats

	PacketsSent=`dmcli eRT getv Device.MoCA.Interface.1.Stats.PacketsSent | grep value | awk '{print $5}'`
	PacketsReceived=`dmcli eRT getv Device.MoCA.Interface.1.Stats.PacketsReceived | grep value | awk '{print $5}'`
	ErrorsSent=`dmcli eRT getv Device.MoCA.Interface.1.Stats.ErrorsSent | grep value | awk '{print $5}'`
	ErrorsReceived=`dmcli eRT getv Device.MoCA.Interface.1.Stats.ErrorsReceived | grep value | awk '{print $5}'`
	DiscardPacketsSent=`dmcli eRT getv Device.MoCA.Interface.1.Stats.DiscardPacketsSent | grep value | awk '{print $5}'`
	DiscardPacketsReceived=`dmcli eRT getv Device.MoCA.Interface.1.Stats.DiscardPacketsReceived | grep value | awk '{print $5}'`

	EgressNumFlows=`dmcli eRT getv Device.MoCA.Interface.1.QoS.EgressNumFlows | grep value | awk '{print $5}'`
	IngressNumFlows=`dmcli eRT getv Device.MoCA.Interface.1.QoS.IngressNumFlows | grep value | awk '{print $5}'`

	echo "RDKB_SELFHEAL : MoCA Statistics info is below"
	echo "RDKB_SELFHEAL : PacketsSent=$PacketsSent PacketsReceived=$PacketsReceived ErrorsSent=$ErrorsSent ErrorsReceived=$ErrorsReceived"
	
	echo "RDKB_SELFHEAL : DiscardPacketsSent=$DiscardPacketsSent DiscardPacketsReceived=$DiscardPacketsReceived"
	echo "RDKB_SELFHEAL : EgressNumFlows=$EgressNumFlows IngressNumFlows=$IngressNumFlows"

		
}