#!/bin/sh

source /fss/gw/usr/ccsp/tad/corrective_action.sh
source /etc/log_timestamp.sh

if [ -f /etc/device.properties ]; then
   source /etc/device.properties
fi

TMPFS_THRESHOLD=85
max_count=12
DELAY=30
	timestamp=`getDate`

    totalMemSys=`free | awk 'FNR == 2 {print $2}'`
    usedMemSys=`free | awk 'FNR == 2 {print $3}'`
    freeMemSys=`free | awk 'FNR == 2 {print $4}'`

    echo_t "RDKB_SYS_MEM_INFO_SYS : Total memory in system is $totalMemSys at timestamp $timestamp"
    echo_t "RDKB_SYS_MEM_INFO_SYS : Used memory in system is $usedMemSys at timestamp $timestamp"
    echo_t "RDKB_SYS_MEM_INFO_SYS : Free memory in system is $freeMemSys at timestamp $timestamp"

    # RDKB-7017	
    echo_t "USED_MEM:$usedMemSys"
    echo_t "FREE_MEM:$freeMemSys"

    # RDKB-7195
    if [ "$BOX_TYPE" == "XB3" ]; then
        iccctl_info=`iccctl mal`
        echo_t "ICCCTL_INFO : $iccctl_info"

        #RDKB-7474
        iccctlMemInfo=`echo $iccctl_info | sed -e 's/.*Total in use//g'`
        inUse=`echo "$iccctlMemInfo" | cut -f2 -d: | cut -f1 -d, | tr -d " "`
        freeMem=`echo "$iccctlMemInfo" | cut -f3 -d: | cut -f1 -d, | tr -d " "`
        total=`echo "$iccctlMemInfo" | cut -f4 -d: | cut -f2 -d" "`

        # Calculate the threshold if in use memory is greater than zero
        if [ $inUse -ne 0 ]
        then
           echo_t "ICCCTL_IN_USE:$inUse"
           thresholdReached=$(( $inUse * 100 / $total ))

           # Log a message if threshold value of 25 is reached
           if [ $thresholdReached -gt 25 ]
           then
              echo_t "ICCCTL_INFO:ICC Memory is above threshold $thresholdReached"
           else
              echo_t "ICCCTL_INFO:ICC Memory is below threshold $thresholdReached"
           fi
        else
            echo_t "ICCCTL_IN_USE:0"
        fi

    fi

    LOAD_AVG=`uptime | awk -F'[a-z]:' '{ print $2}' | sed 's/^ *//g' | sed 's/,//g' | sed 's/ /:/g'`
    # RDKB-7017	
    echo_t "RDKB_LOAD_AVERAGE : Load Average is $LOAD_AVG at timestamp $timestamp"
    
    #RDKB-7411
    LOAD_AVG_15=`echo $LOAD_AVG | cut -f3 -d:`
    echo_t "LOAD_AVERAGE:$LOAD_AVG_15"
    
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
	timestamp=`getDate`
    # RDKB-7017	
    echo_t "RDKB_CPU_USAGE : CPU usage is $Curr_CPULoad at timestamp $timestamp"
    echo_t "USED_CPU:$Curr_CPULoad"

    # RDKB-7412
   	CPU_INFO=`mpstat | tail -1 | tr -s ' ' ':' | cut -d':' -f5-`
	MPSTAT_USR=`echo $CPU_INFO | cut -d':' -f1`
	MPSTAT_SYS=`echo $CPU_INFO | cut -d':' -f3`
	MPSTAT_NICE=`echo $CPU_INFO | cut -d':' -f2`
	MPSTAT_IRQ=`echo $CPU_INFO | cut -d':' -f5`
	MPSTAT_SOFT=`echo $CPU_INFO | cut -d':' -f6`
	MPSTAT_IDLE=`echo $CPU_INFO | cut -d':' -f9`

	echo_t "MPSTAT_USR:$MPSTAT_USR"
	echo_t "MPSTAT_SYS:$MPSTAT_SYS"
	echo_t "MPSTAT_NICE:$MPSTAT_NICE"
	echo_t "MPSTAT_IRQ:$MPSTAT_IRQ"
	echo_t "MPSTAT_SOFT:$MPSTAT_SOFT"
	echo_t "MPSTAT_IDLE:$MPSTAT_IDLE"

	USER_CPU=`echo $MPSTAT_USR | cut -d'.' -f1`
	count=`syscfg get process_memory_log_count`
	count=$((count + 1))
	echo_t "Count is $count"

	if [ "$count" -eq "$max_count" ]
	then
		echo_t "RDKB_PROC_MEM_LOG: Process Memory log at $timestamp is"
		echo_t ""
		top -m -b n 1
		syscfg set process_memory_log_count 0	
		syscfg commit
	
	else
		# RDKB-6162
		if [ "$USER_CPU" -ge "25" ]; then
			echo_t "RDKB_PROC_USAGE_LOG: Top 5 CPU USAGE Process at $timestamp is"
			echo_t ""
			top_cmd="top -bn1 | head -n10 | tail -6"
			eval $top_cmd
		fi
		syscfg set process_memory_log_count $count	
		syscfg commit
	fi

	echo_t "================================================================================"
	echo_t ""
	echo_t "RDKB_DISK_USAGE: Systems Disk Space Usage log at $timestamp is"
	echo_t ""
	disk_usage="df"
	eval $disk_usage
	count=$((count + 1))

	########### df related ########
        TMPFS_CUR_USAGE=0
	TMPFS_CUR_USAGE=`df /tmp | tail -1 | awk '{print $(NF-1)}' | cut -d"%" -f1`
	if [ $TMPFS_CUR_USAGE -ge $TMPFS_THRESHOLD ]
	then
		echo_t "TMPFS_USAGE:$TMPFS_CUR_USAGE"
	fi
