# Bash Recon Scan - BRS

It is a bash script that can use nc/netcat/ncat and fping/ping to find hosts in a network, and then scan several ports (1-1024 and 8000-8100) of the active hosts found.

It is very usefull to use when you want to search and scan hosts in a network and you dont have better tools than nc and ping.

The netmask that are currently supported are: **/24** and **/16**.

This tool doesn't need root pvivileges.

In the help of the tool you can find the main usage:
```bash
└──╼ $./brs.sh 
./brs.sh <protocols> <ip_addres>/<netmask> [<Port>]
./brs.sh tcp 192.168.0.1/24 22
./brs.sh icmp 192.168.0.1/16
./brs.sh tcp,icmp 192.168.0.1/24 22
The output will be saved in <ip>/24_<proto>_brs_recon.txt
All the active hosts will appear in the terminal and saved in the file active_ips.txt
Available protocols are: tcp,icmp (you can select all at the same time)
The tool will scan ports some ranges of ports of the active hosts: 1-1024 and 8000-8100
The data of the scanned ports will be saved inside port_scan.txt
```

You can find usufull also the following oneliners:

Recon a /24 network using nc
```bash
for j in $(seq 1 254); do nc -v -n -z -w 1 192.168.1.$j 22 2>> s.txt; done; grep -v "Connection refused\|Version\|bytes\| out" s.txt | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' s.txt | sort | uniq > ips.txt;

#Faster recon using timeout instead of -w and -z
for j in $(seq 1 254); do timeout 0.5 nc -v -n 192.168.1.$j 22 2>> s.txt; done; grep -v "Connection refused\|Version\|bytes\| out" s.txt | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' s.txt | sort | uniq > ips.txt;
```

Search for open ports reading host from ips.txt
```bash
while read host; do nc -v -z -n $host 1-1024 2>> ps.txt; done < ips.txt; cat ps.txt | grep -v "Connection refused\|Version\|bytes\| out";
```

If you **cant select a range of ports** in your netcat version, use this oneliner to scan for ports (reading from a file)
```bash
while read host; do for p in $(seq 1 1024); do nc -v -z -n -w 1 $host $p 2>> ps.txt; done; done < ips.txt; cat ps.txt | grep -v "Connection refused\|Version\|bytes\| out";

#Faster scan using timeout instead of -w and -z
while read host; do for p in $(seq 1 1024); do timeout 0.5 nc -v -n $host $p 2>> ps.txt; done; done < ips.txt; cat ps.txt | grep -v "Connection refused\|Version\|bytes\| out";
```