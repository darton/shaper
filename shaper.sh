#!/bin/bash

#  (C) Copyright Dariusz Kowalczyk
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License Version 2 as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

PATH=/sbin:/usr/sbin/:/bin:/usr/bin:$PATH

confdir=.
shaper_file=shaper.conf

WAN=enp0s3
LAN=enp0s8

#Default value when was not declared in shaper.conf file
DEFAULT_ISP_RX_LIMIT=800000kbit
DEFAULT_ISP_TX_LIMIT=800000kbit
DEFAULT_GW_TO_LAN_LIMIT=100000kbit
DEFAULT_GW_TO_WAN_LIMIT=100000kbit
DEFAULT_LAN_UNCLASSIFIED_LIMIT=128kbit
DEFAULT_WAN_UNCLASSIFIED_LIMIT=128kbit


[[ -f $confdir/$shaper_file ]] || touch $confdir/$shaper_file

function shaper_cmd {

if [ "$1" = "stop" ]; then
        tc qdisc del dev $LAN root 2> /dev/null
        tc qdisc del dev $WAN root 2> /dev/null
        iptables -t mangle -F
        iptables -t mangle -X
fi

if [ "$1" = "start" ]; then

        shaper_cmd stop
        delimiter=$IFS

        while IFS='=' read arg1 arg2; do
            if [ "$arg1" = "ISP_RX_LIMIT" ]; then
                ISP_RX_LIMIT=$arg2
            fi
            if [ "$arg1" = "ISP_TX_LIMIT" ]; then
                ISP_TX_LIMIT=$arg2
            fi
            if [ "$arg1" = "LAN_UNCLASSIFIED_LIMIT" ]; then
                LAN_UNCLASSIFIED_LIMIT=$arg2
            fi
            if [ "$arg1" = "WAN_UNCLASSIFIED_LIMIT" ]; then
                WAN_UNCLASSIFIED_LIMIT=$arg2
            fi
            if [ "$arg1" = "GW_TO_LAN_LIMIT" ]; then
                GW_TO_LAN_LIMIT=$arg2
            fi
            if [ "$arg1" = "GW_TO_WAN_LIMIT" ]; then
                GW_TO_WAN_LIMIT=$arg2
            fi
        done < <(cat $confdir/$shaper_file|grep -v \#)

    IFS=$delimiter

            if [ -z "$ISP_RX_LIMIT" ]; then
                ISP_RX_LIMIT=$DEFAULT_ISP_RX_LIMIT
            fi
            if [ -z "$ISP_TX_LIMIT" ]; then
                ISP_TX_LIMIT=$DEFAULT_ISP_TX_LIMIT
            fi
            if [ -z "$LAN_UNCLASSIFIED_LIMIT" ]; then
                LAN_UNCLASSIFIED_LIMIT=$DEFAULT_LAN_UNCLASSIFIED_LIMIT
            fi
            if [ -z "$WAN_UNCLASSIFIED_LIMIT" ]; then
                WAN_UNCLASSIFIED_LIMIT=$DEFAULT_WAN_UNCLASSIFIED_LIMIT
            fi
            if [ -z "$GW_TO_LAN_LIMIT" ]; then
                GW_TO_LAN_LIMIT=$DEFAULT_GW_TO_LAN_LIMIT
            fi
            if [ -z "$GW_TO_WAN_LIMIT" ]; then
                GW_TO_WAN_LIMIT=$DEFAULT_GW_TO_WAN_LIMIT
            fi

        echo ISP_RX_LIMIT=$ISP_RX_LIMIT
        echo ISP_TX_LIMIT=$ISP_TX_LIMIT
        echo LAN_NONCLASIFIED_LIMIT=$LAN_NONCLASIFIED_LIMIT
        echo WAN_NONCLASIFIED_LIMIT=$WAN_NONCLASIFIED_LIMIT
        echo GW_TO_LAN_LIMIT=$GW_TO_LAN_LIMIT
        echo GW_TO_WAN_LIMIT=$GW_TO_WAN_LIMIT

        BURST="burst 15k"

#LAN
        if [ ! -z "$LAN" ]; then

# Set global limit for LAN interface
        tc qdisc add dev $LAN root handle 1:0 htb default 3 r2q 1
        tc class add dev $LAN parent 1:0 classid 1:1 htb rate 900000kbit ceil 900000kbit $BURST quantum 1500

# Set limit for all traffic from Internet to LAN
        tc class add dev $LAN parent 1:1 classid 1:2 htb rate $ISP_RX_LIMIT ceil $ISP_RX_LIMIT $BURST quantum 1500

#Set default limit for traffic from Internet to LAN
        tc class add dev $LAN parent 1:1 classid 1:3 htb rate 8kbit ceil $LAN_UNCLASSIFIED_LIMIT prio 7 quantum 1500
        tc qdisc add dev $LAN parent 1:3 sfq perturb 10

#Set limit from for traffic from GATEWAY to LAN
        tc class add dev $LAN parent 1:1 classid 1:4 htb rate 128kbit ceil $GW_TO_LAN_LIMIT $BURST prio 4 quantum 1500
        tc qdisc add dev $LAN parent 1:4 sfq perturb 10
        iptables -t mangle -A OUTPUT -o $LAN -j CLASSIFY --set-class 1:4
        fi

#WAN
        if [ ! -z "$WAN" ]; then

# Set limit for all traffic from WAN to Internet
        tc qdisc add dev $WAN root handle 2:0 htb default 3 r2q 1
        tc class add dev $WAN parent 2:0 classid 2:1 htb rate $ISP_TX_LIMIT ceil $ISP_TX_LIMIT $BURST quantum 1500

# Set default limit for traffic from WAN to Internet
        tc class add dev $WAN parent 2:1 classid 2:3 htb rate 8kbit ceil $WAN_UNCLASSIFIED_LIMIT prio 7 quantum 1500
        tc qdisc add dev $WAN parent 2:3 sfq perturb 10
        tc filter add dev $WAN parent 2:0 protocol ip prio 9 u32 match ip dst 0/0 flowid 2:3

#Set limit for traffic from GATEWAY to WAN
        tc class add dev $WAN parent 2:1 classid 2:4 htb rate 128kbit ceil $GW_TO_WAN_LIMIT $BURST prio 4 quantum 1500
        tc qdisc add dev $WAN parent 2:4 sfq perturb 10
        iptables -t mangle -A OUTPUT -o $WAN -j CLASSIFY --set-class 2:4
        fi

#Set limit for Customers host
        network_list=$(cat $confdir/$shaper_file |grep filter |awk '{print $3}'|awk -F\. '{print $1"."$2"."$3}'|sort -u)
        for net in $network_list; do
            echo $net | { IFS='.' read -r octet1 octet2 octet3;
            iptables -t mangle -N COUNTERSIN$octet3;
            iptables -t mangle -N COUNTERSOUT$octet3;
            iptables -t mangle -I FORWARD -i $WAN -d $net.0/24 -j COUNTERSIN$octet3;
            iptables -t mangle -I FORWARD -o $WAN -s $net.0/24 -j COUNTERSOUT$octet3;}
        done
        while read arg1 arg2 arg3 arg4; do
        if [ ! -z "$WAN" ]; then
            if [ "$arg2" = "class_up" ]; then
                tc class add dev $WAN parent 2:1 classid 2:$arg1 htb rate $arg3 ceil $arg4 $BURST prio 2 quantum 1500
                tc qdisc add dev $WAN parent 2:$arg1 sfq perturb 10
            fi
        fi
        if [ ! -z "$LAN" ]; then
            if [ "$arg2" = "class_down" ]; then
                tc class add dev $LAN parent 1:2 classid 1:$arg1 htb rate $arg3 ceil $arg4 $BURST prio 2 quantum 1500
                tc qdisc add dev $LAN parent 1:$arg1 sfq perturb 10
            fi
        fi
            if [ "$arg2" = "filter" ]; then
                echo $arg3 | { IFS='.' read -r octet1 octet2 octet3 octet4;
                iptables -t mangle -A COUNTERSOUT$octet3 -s $arg3 -j CLASSIFY --set-class 2:$arg1;
                iptables -t mangle -A COUNTERSIN$octet3 -d $arg3 -j CLASSIFY --set-class 1:$arg1; }
            fi
        done < <(cat $confdir/$shaper_file|grep -v \#)
fi

if [ "$1" = "stats" ]; then
        for IPT_TABLE_ELEMENT in $(iptables -t mangle -nL FORWARD |grep COUNTERSOUT |awk '{print $1}'); do
            iptables -t mangle -nvxL $IPT_TABLE_ELEMENT |tail -n +3 | awk '{print $8 " "$2}' |grep -v 0.0.0.0 >> /tmp/upload.tmp
        done
        for IPT_TABLE_ELEMENT in $(iptables -t mangle -nL FORWARD |grep COUNTERSIN |awk '{print $1}'); do
            iptables -t mangle -nvxL $IPT_TABLE_ELEMENT |tail -n +3 | awk '{print $9 " "$2}' |grep -v 0.0.0.0 >> /tmp/download.tmp
        done
        iptables -t mangle -Z
        join /tmp/upload.tmp /tmp/download.tmp | grep -v  " 0 0"
        rm /tmp/upload.tmp /tmp/download.tmp
fi

if [ "$1" = "status" ]; then

    iptables -t mangle -nvL

    echo
    echo "$LAN interface"
    echo "----------------"
    for TC_OPTIONS in qdisc class filter; do
        if [ ! -z "$LAN" ]; then
            echo
            echo "$TC_OPTIONS"
            echo "------"
            tc $TC_OPTIONS show dev $LAN
        fi
    done

    echo
    echo "$WAN interface"
    echo "----------------"
    for TC_OPTIONS in qdisc class filter; do
        if [ ! -z "$WAN" ]; then
            echo
            echo "$TC_OPTIONS"
            echo "------"
            tc $TC_OPTIONS show dev $WAN
        fi
    done

fi
}

case "$1" in

    'stop')
        shaper_cmd stop
    ;;
    'start')
        shaper_cmd start
    ;;
    'restart')
        shaper_cmd stop
        shaper_cmd start
    ;;
    'status')
        shaper_cmd status
    ;;
    'stats')
        shaper_cmd stats
    ;;
        *)
        echo -e "\nUsage: shaper.sh start|stop|restart"
    ;;

esac
