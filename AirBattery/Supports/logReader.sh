#!/bin/bash
if [ "x$1" = "xmac" ]; then
    PRED='subsystem == "com.apple.bluetooth" AND (category == "CBStackDeviceMonitor" OR category == "Server.GATT") AND (eventMessage CONTAINS "Battery" OR eventMessage CONTAINS "statedump: 0x0011" OR eventMessage CONTAINS "statedump: 0x0014" OR eventMessage CONTAINS "statedump: 0x001A" OR eventMessage CONTAINS "statedump: 0x001D")'
    # Return raw text for the typed Swift parser. Pass the cursor as an argument,
    # not a process-global environment variable shared with concurrent scans.
    if [ -n "$3" ]; then
        exec /usr/bin/nice -n 19 /usr/bin/log show --style compact --info --predicate "$PRED" --start "$3"
    else
        exec /usr/bin/nice -n 19 /usr/bin/log show --style compact --info --predicate "$PRED" --last "${2:-10m}"
    fi
else
    syslog=$1
    type=$2
    id=$3
    
    data=`$syslog $type -u $id --process SpringBoard -m '"Accessory Category" = Pencil;' -T SpringBoard`
    batt=`echo "$data"|grep "Current Capacity"|grep -o "[0-9]*"|sed -n '$p'`
    stat=`echo "$data"|grep "Is Charging"|grep -o "[0-9]*"|sed -n '$p'`
    model=`echo "$data"|grep "Product ID"|grep -o "[0-9]*"|sed -n '$p'`
    vendor=`echo "$data"|grep "Vendor ID"|grep -v Source|grep -o "[0-9]*"|sed -n '$p'`
    if [ x"$vendor" = "x76" ]; then vendor="Apple"; else vendor="Other"; fi
    
    #data=`$syslog $type -u $id -m 'name = Pencil' --process SpringBoard -T SpringBoard|tr ';' '\n'`
    #batt=`echo "$data"|grep "percentCharge ="|grep -o "[0-9]*"|sed -n '$p'`
    #stat=`echo "$data"|grep "charging ="|tr -d " "|sed 's/charging=//g'|sed -n '$p'`
    #model=`echo "$data"|grep "productIdentifier ="|grep -o "[0-9]*"|sed -n '$p'`
    #vendor=`echo "$data"|grep "vendor ="|tr -d " "|sed 's/vendor=//g'|sed -n '$p'`
    #if [ x"$stat" = "xYES" ]; then stat=1; else stat=0; fi
    echo "{\"level\": $batt, \"status\": $stat, \"model\": \"$model\", \"vendor\": \"$vendor\"}"
fi
