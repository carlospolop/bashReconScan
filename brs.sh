#!/bin/bash

HELP="$0 <protocols> <ip_addres>/<netmask> [<Port>]\n$0 tcp 192.168.0.1/24 22\n$0 icmp 192.168.0.1/16\n$0 tcp,icmp 192.168.0.1/24 22\nThe output will be saved in <ip>/24_<proto>_brs_recon.txt\nAll the active hosts will appear in the terminal and saved in the file active_ips.txt\nAvailable protocols are: tcp,icmp (you can select all at the same time)\nThe tool will scan ports some ranges of ports of the active hosts: 1-1024 and 8000-8100\nThe data of the scanned ports will be saved inside port_scan.txt";

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ] ; then
    echo -e $HELP;
	exit 1;
fi

FILENAME_SCANPORTS="port_scan.txt"
IP=$(echo $2 | cut -d "/" -f 1)
NETMASK=$(echo $2 | cut -d "/" -f 2)
ACTIVE_IPS="active_ips.txt"

rm -f *_brs_recon.txt 2>/dev/null
rm -f $FILENAME_SCANPORTS 2>/dev/null
rm $ACTIVE_IPS 2>/dev/null


#Look for nc
NC=$(which nc 2>/dev/null)
if [ -z "$NC" ]; then
	NC=$(which netcat 2>/dev/null);
fi
if [ -z "$NC" ]; then
	NC=$(which ncat 2>/dev/null);
fi
if [ -z "$NC" ]; then
	echo "Neither netcat nor nc nor ncat was found, tcp and scan cannot be done";
else
	NC_SCAN="$NC -v -n -z -w 1"
	$($NC 127.0.0.1 65321 &>/dev/null)
	if [ $? -eq 2 ]
	then
		NC_SCAN="timeout 0.7 $NC -v -n" 
	fi
	echo $NC_SCAN;
fi


function tcp_recon(){
	IP3=$(echo $1 | cut -d "." -f 1,2,3)
	PORT=$2
	FILENAME_TCP=$3
	rm -f $FILENAME_TCP 2>/dev/null

	for j in $(seq 1 254)
	do 
		$($NC_SCAN $IP3.$j $PORT 2>> $FILENAME_TCP.temp;)
	done
	
	grep -v "Connection refused\|Version\|bytes\| out" $FILENAME_TCP.temp | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort | uniq >> $FILENAME_TCP;
	rm $FILENAME_TCP.temp;
}

function icmp_recon(){
	IP3=$(echo $1 | cut -d "." -f 1,2,3)
	FILENAME_ICMP=$2
	rm -f $FILENAME_ICMP 2>/dev/null
	
	for j in $(seq 0 255)
	do
		if timeout 0.7 ping -c 1 $IP3.$j  &> /dev/null
		then
			echo $IP3.$j >> $FILENAME_ICMP;
		fi
	done
}

function tcp_scan(){
	HOST=$1
	FILENAME_SCANPORTS_temp=$FILENAME_SCANPORTS".temp"

	#Start port scanning
	for PORT in {1..1024} {8000..8100}
	do
		$($NC_SCAN $HOST $PORT 2>> $FILENAME_SCANPORTS_temp;)
	done
}



#TCP option
if [[ $1 == *tcp* ]]; then
	#Check parameters
	if  [ "$#" -ne 3 ] ; then
		echo "tcp option needs <ip_addres>/<netmask> <Port>";
		exit 1;
	fi

	if [ -z "$NC" ]; then #No nc
		exit 1;
	fi
	
	echo "Starting TCP recon"
	FILENAME=$IP"_"$NETMASK"_tcp_brs_recon.txt"
	PORT=$3
	
	#Check netmask
	if [[ $NETMASK == "24" ]]; then
		echo "netmask /24 detected, starting..."
		tcp_recon $IP $PORT $FILENAME
	
	elif [[ $NETMASK == "16" ]]; then
		echo "netmask /16 detected, starting..."
		for i in $(seq 0 255)
		do	
			NEWIP=$(echo $IP | cut -d "." -f 1,2).$i.1
			NEWFILE=$NEWIP-24_$1_recon.txt
			tcp_recon $NEWIP $PORT $NEWFILE
		done
	fi
fi

#ICMP option
if [[ $1 == *icmp* ]]; then
	#Check parameters
	if  [ "$#" -ne 2 ]; then
		if [[ ! $1 == *tcp* ]]; then #If bad num of params and not tcp
			echo "icmp option needs only <ip_addres>/<netmask>";
			exit 1;
		fi
	fi
	
	echo "Starting ICMP recon"
	FILENAME=$IP"_"$NETMASK"_icmp_brs_recon.txt"
	
	#If fping
	FPING=$(which fping)
	if [ ! -z "$FPING" ]; then
		echo "Fping was found, using it..."
		fping -a -q -g $2 > $FILENAME;
	else
		#It no fping, use ping
		PING=$(which ping)
		if [ -z "$PING" ]
		then
			echo "Ping not found";
			exit 1;
		fi
		
		#Check netmask
		if [[ $NETMASK == "24" ]]; then
			echo "netmask /24 detected, starting..."
			icmp_recon $IP $FILENAME
		
		elif [[ $NETMASK == "16" ]]; then
			echo "netmask /16 detected, starting..."
			for i in $(seq 1 254)
			do	
				NEWIP=$(echo $IP | cut -d "." -f 1,2).$i.1
				NEWFILE=$NEWIP/24_$1_recon.txt
				icmp_recon $NEWIP $NEWFILE
			done
		fi
	fi
fi


cat *_brs_recon.txt | sort | uniq > $ACTIVE_IPS;
rm -f *_brs_recon.txt;
echo "Active IPs:"
cat $ACTIVE_IPS;

#If no nc, stop here
if [ -z "$NC" ] #No nc
then
	exit 1;
fi

echo "Starting scanning ports of active hosts";
rm -f $FILENAME_SCANPORTS_temp 2>/dev/null

#Scan each host in background
while read host
do
	tcp_scan $host
done < $ACTIVE_IPS

cat $FILENAME_SCANPORTS_temp | grep -v "Connection refused\|Version\|bytes\| out" | sort | uniq >> $FILENAME_SCANPORTS;
rm -f $FILENAME_SCANPORTS_temp
cat $FILENAME_SCANPORTS;
