#!/bin/bash

INTERNET_IF="enp0s10"
INTERNET_NET="193.136.0.0/15"
INTERNET_IP="193.136.0.254" # in the diagram it says 87.248.214.97but it would not make sense mask wise, so we changed it
INTERNET_EDEN="193.136.212.1"
INTERNET_DNS2="193.137.16.75"

INTERNAL_IF="enp0s9"
INTERNAL_NET="192.168.10.0/24"
INTERNAL_IP="192.168.10.254"
INTERNAL_FTP_SERVER="192.168.10.2"
INTERNAL_DATASTORE_SERVER="192.168.10.3"

DMZ_IF="enp0s8"
DMZ_NET="23.214.219.128/25"
DMZ_IP="23.214.219.254"
DMZ_SMTP_SERVER="23.214.219.129"
DMZ_DNS1_SERVER="23.214.219.130"
DMZ_MAIL_SERVER="23.214.219.131"
DMZ_WWW_SERVER="23.214.219.132"
DMZ_VPN_GW_SERVER="23.214.219.133"

# Interface Setup
ifconfig $DMZ_IF      $DMZ_IP      netmask 255.255.255.128 up
ifconfig $INTERNAL_IF $INTERNAL_IP netmask 255.255.255.0 up
ifconfig $INTERNET_IF $INTERNET_IP netmask 255.254.0.0 up

# Activates Ip Forwarding & FTP
modprobe nf_conntrack_ftp
modprobe nf_nat_ftp
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.netfilter.nf_conntrack_helper=1

# Disable firewall
systemctl stop firewalld
systemctl disable firewalld

# Iptables Clear
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Drop everything by default
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Iptables configuration
## Firewall configuration to protect the router
### DNS name resolution requests sent to outside servers
iptables -A OUTPUT -o $INTERNET_IF -p udp --dport 53 -m state --state NEW -j ACCEPT
iptables -A OUTPUT -o $INTERNET_IF -p tcp --dport 53 -m state --state NEW -j ACCEPT

### SSH connections to the router system, if originated at the internal network or at the VPN gateway ( vpn-gw)
iptables -A INPUT -i $INTERNAL_IF -s $INTERNAL_NET -p tcp --dport 22 -m state --state NEW -j ACCEPT
iptables -A INPUT -i $DMZ_IF -s $DMZ_VPN_GW_SERVER -p tcp --dport 22 -m state --state NEW -j ACCEPT

## Firewall configuration to authorize direct communications (without NAT): 
### Domain name resolutions using the dns server
iptables -A FORWARD -d $DMZ_DNS1_SERVER -p udp --dport 53 -m state --state NEW -j ACCEPT
iptables -A FORWARD -d $DMZ_DNS1_SERVER -p tcp --dport 53 -m state --state NEW -j ACCEPT
### The dns server should be able to resolve names using DNS servers on the Internet ( dns2 and also others). 
iptables -A FORWARD -i $DMZ_IF -o $INTERNET_IF -s $DMZ_DNS1_SERVER -p udp --dport 53 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $DMZ_IF -o $INTERNET_IF -s $DMZ_DNS1_SERVER -p tcp --dport 53 -m state --state NEW -j ACCEPT
### The dns and dns2 servers should be able to synchronize the contents of DNS zones. 
iptables -A FORWARD -i $DMZ_IF -o $INTERNET_IF -s $DMZ_DNS1_SERVER -d $INTERNET_DNS2 -p tcp --dport 53 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $INTERNET_IF -o $DMZ_IF -s $INTERNET_DNS2 -d $DMZ_DNS1_SERVER -p tcp --dport 53 -m state --state NEW -j ACCEPT
### SMTP connections to the smtp server. 
iptables -A FORWARD -d $DMZ_SMTP_SERVER -p tcp --dport 25 -m state --state NEW -j ACCEPT
### POP and IMAP connections to the mail server. 
iptables -A FORWARD -d $DMZ_MAIL_SERVER -p tcp -m multiport --dports 110,143,993,995 -m state --state NEW -j ACCEPT
### HTTP and HTTPS connections to the www server. 
iptables -A FORWARD -d $DMZ_WWW_SERVER -p tcp -m multiport --dports 80,443 -m state --state NEW -j ACCEPT
### OpenVPN connections to the vpn-gw server. 
iptables -A FORWARD -d $DMZ_VPN_GW_SERVER -p udp --dport 1194 -m state --state NEW -j ACCEPT
### VPN clients connected to the gateway ( vpn-gw) should be able to connect to all services in the Internal network (assume the gateway does SNAT/MASQUERADING for communications received from clients).
iptables -A FORWARD -i $DMZ_IF -o $INTERNAL_IF -s $DMZ_VPN_GW_SERVER -m state --state NEW -j ACCEPT

## Firewall configuration for connections to the external IP address of the firewall (using NAT)
###  FTP connections (in passive and active modes) to the ftp server.
PASV_MIN=30000
PASV_MAX=30050

iptables -t nat -A PREROUTING -i $INTERNET_IF -d $INTERNET_IP -p tcp --dport 21 -j DNAT --to-destination $INTERNAL_FTP_SERVER
iptables -t nat -A PREROUTING -i $INTERNET_IF -d $INTERNET_IP -p tcp --dport ${PASV_MIN}:${PASV_MAX} -j DNAT --to-destination $INTERNAL_FTP_SERVER

iptables -A FORWARD -i $INTERNET_IF -o $INTERNAL_IF -d $INTERNAL_FTP_SERVER -p tcp --dport 21 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $INTERNET_IF -o $INTERNAL_IF -d $INTERNAL_FTP_SERVER -p tcp --dport 20 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $INTERNET_IF -o $INTERNAL_IF -d $INTERNAL_FTP_SERVER -p tcp --dport ${PASV_MIN}:${PASV_MAX} -m state --state NEW -j ACCEPT

### SSH connections to the datastore server, but only if originated at the eden or dns2 servers.
iptables -t nat -A PREROUTING -i $INTERNET_IF -s $INTERNET_EDEN -d $INTERNET_IP -p tcp --dport 22 -j DNAT --to-destination $INTERNAL_DATASTORE_SERVER
iptables -t nat -A PREROUTING -i $INTERNET_IF -s $INTERNET_DNS2 -d $INTERNET_IP -p tcp --dport 22 -j DNAT --to-destination $INTERNAL_DATASTORE_SERVER

iptables -A FORWARD -i $INTERNET_IF -o $INTERNAL_IF -s $INTERNET_EDEN -d $INTERNAL_DATASTORE_SERVER -p tcp --dport 22 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $INTERNET_IF -o $INTERNAL_IF -s $INTERNET_DNS2 -d $INTERNAL_DATASTORE_SERVER -p tcp --dport 22 -m state --state NEW -j ACCEPT

## Firewall configuration for communications from the internal network to the outside (using NAT)
#iptables -t nat -A POSTROUTING -s $INTERNAL_NET -o $INTERNET_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -s $INTERNAL_NET -o $INTERNET_IF -j SNAT --to-source $INTERNET_IP
### Domain name resolutions using DNS
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -s $INTERNAL_NET -p udp --dport 53 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -s $INTERNAL_NET -p tcp --dport 53 -m state --state NEW -j ACCEPT
### HTTP, HTTPS and SSH connections
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -s $INTERNAL_NET -p tcp -m multiport --dports 80,443,22 -m state --state NEW -j ACCEPT
### FTP connections (in passive and active modes) to external FTP servers
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -s $INTERNAL_NET -p tcp --dport 21 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -s $INTERNAL_NET -p tcp --dport 20 -m state --state NEW -j ACCEPT

# Suricata
## Configure Suricata to analyze all traffic received and sent by the router system
iptables -I INPUT 1 -j NFQUEUE --queue-num 0
iptables -I OUTPUT 1 -j NFQUEUE --queue-num 0
iptables -I FORWARD 1 -j NFQUEUE --queue-num 0


## Copies the suricata.yaml no suricata.yaml default location
cp suricata.yaml /etc/suricata/suricata.yaml
## This is the additional rules file made to ensure XSS, SQLi and port scanning is detected and blocked
cp local.rules /var/lib/suricata/rules/local.rules

## Run suricata in IDS mode, with NFQUEUE as the capture method, and with the highest level of verbosity ( -vvvv)
suricata -c /etc/suricata/suricata.yaml -vvvv -q 0
