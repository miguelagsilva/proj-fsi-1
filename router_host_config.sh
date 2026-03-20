#!/bin/bash

INTERNET_IF="enp0s10"
INTERNET_IP="193.136.0.254"
INTERNET_NET="193.136.0.0/16"
INTERNET_EDEN="193.136.212.1"
INTERNET_DNS2="193.137.16.75"

INTERNAL_NET="192.168.10.0/24"
INTERNAL_IF="enp0s9"
INTERNAL_FTP_SERVER="192.168.10.2"
INTERNAL_DATASTORE_SERVER="192.168.10.3"

DMZ_IF="enp0s8"
DMZ_NET="23.214.219.128/25"
DMZ_SMTP_SERVER="23.214.219.129"
DMZ_DNS1_SERVER="23.214.219.130"
DMZ_DNS2_SERVER="23.214.219.134"
DMZ_MAIL_SERVER="23.214.219.131"
DMZ_WWW_SERVER="23.214.219.132"
DMZ_VPN_GW_SERVER="23.214.219.133"

# Interface Setup
ifconfig $DMZ_IF 23.214.219.254 netmask 255.255.255.128 up
ifconfig $INTERNAL_IF 192.168.10.254 netmask 255.255.255.0 up
ifconfig $INTERNET_IF 193.136.0.254 netmask 255.255.0.0 up

# Activates Ip Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.netfilter.nf_conntrack_helper=1

# Iptables Clear
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Iptables configuration
## Firewall configuration to protect the router
### DNS name resolution requests sent to outside servers
iptables -A OUTPUT -p udp --sport domain -j ACCEPT
iptables -A INPUT  -p udp --dport domain -j ACCEPT

### SSH connections to the router system, if originated at the internal network or at the VPN gateway ( vpn-gw)
iptables -A INPUT  -p tcp --dport ssh -s $INTERNAL_NET -j ACCEPT
iptables -A OUTPUT -p tcp --sport ssh -d $INTERNAL_NET -j ACCEPT
iptables -A INPUT  -p tcp --dport ssh -s $DMZ_VPN_GW_SERVER -j ACCEPT
iptables -A OUTPUT -p tcp --sport ssh -d $DMZ_VPN_GW_SERVER -j ACCEPT

## Firewall configuration to authorize direct communications (without NAT): 
### Domain name resolutions using the dns server
iptables -A FORWARD -d $DMZ_DNS1_SERVER -p udp --dport domain -j ACCEPT
iptables -A FORWARD -s $DMZ_DNS1_SERVER -p udp --sport domain -j ACCEPT
### The dns server should be able to resolve names using DNS servers on the Internet ( dns2 and also others). 
iptables -A FORWARD -d $DMZ_DNS1_SERVER -p udp --dport domain -j ACCEPT
iptables -A FORWARD -s $DMZ_DNS1_SERVER -p udp --sport domain -j ACCEPT
### The dns and dns2 servers should be able to synchronize the contents of DNS zones. 
iptables -A FORWARD -d $DMZ_DNS1_SERVER -s $DMZ_DNS2_SERVER -p udp --dport domain -j ACCEPT
iptables -A FORWARD -s $DMZ_DNS1_SERVER -d $DMZ_DNS2_SERVER -p udp --sport domain -j ACCEPT
iptables -A FORWARD -d $DMZ_DNS1_SERVER -s $DMZ_DNS2_SERVER -p tcp --dport domain -j ACCEPT
iptables -A FORWARD -s $DMZ_DNS1_SERVER -d $DMZ_DNS2_SERVER -p tcp --dport domain -j ACCEPT
### SMTP connections to the smtp server. 
iptables -A FORWARD -d $DMZ_SMTP_SERVER -p tcp --dport smtp -j ACCEPT
iptables -A FORWARD -s $DMZ_SMTP_SERVER -p tcp --sport smtp -j ACCEPT
### POP and IMAP connections to the mail server. 
iptables -A FORWARD -d $DMZ_MAIL_SERVER -p tcp -m multiport --dports pop3,imap -j ACCEPT
iptables -A FORWARD -s $DMZ_MAIL_SERVER -p tcp -m multiport --sports pop3,imap -j ACCEPT
### HTTP and HTTPS connections to the www server. 
iptables -A FORWARD -d $DMZ_WWW_SERVER -p tcp -m multiport --dports http,https -j ACCEPT
iptables -A FORWARD -s $DMZ_WWW_SERVER -p tcp -m multiport --sports http,https -j ACCEPT
### OpenVPN connections to the vpn-gw server. 
iptables -A FORWARD -d $DMZ_VPN_GW_SERVER -p udp --dport openvpn -j ACCEPT
iptables -A FORWARD -s $DMZ_VPN_GW_SERVER -p udp --sport openvpn -j ACCEPT
### VPN clients connected to the gateway ( vpn-gw) should be able to connect to all services in the Internal network (assume the gateway does SNAT/MASQUERADING for communications received from clients).
iptables -A FORWARD -s $DMZ_VPN_GW_SERVER -d $INTERNAL_NET -j ACCEPT
iptables -A FORWARD -d $DMZ_VPN_GW_SERVER -s $INTERNAL_NET -j ACCEPT

## Firewall configuration for connections to the external IP address of the firewall (using NAT)
### SSH connections to the datastore server, but only if originated at the eden or dns2 servers.
iptables -t nat -A PREROUTING -p tcp -s $INTERNET_EDEN -d $INTERNET_IP --dport 22 -j DNAT --to-destination $INTERNAL_DATASTORE_SERVER
iptables -t nat -A PREROUTING -p tcp -s $INTERNET_DNS2 -d $INTERNET_IP --dport 22 -j DNAT --to-destination $INTERNAL_DATASTORE_SERVER

iptables -A FORWARD -p tcp -s $INTERNET_EDEN -d $INTERNAL_DATASTORE_SERVER --dport 22 -j ACCEPT
iptables -A FORWARD -p tcp -s $INTERNET_DNS2 -d $INTERNAL_DATASTORE_SERVER --dport 22 -j ACCEPT

###  FTP connections (in passive and active modes) to the ftp server.
modprobe nf_conntrack_ftp
modprobe nf_nat_ftp
iptables -t nat -A PREROUTING -p tcp -d $INTERNET_IP --dport 21 -j DNAT --to-destination $INTERNAL_FTP_SERVER
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p tcp --dport 21 -m conntrack --ctstate NEW -j ACCEPT

## Firewall configuration for communications from the internal network to the outside (using NAT)
### Domain name resolutions using DNS
iptables -t nat -A POSTROUTING -p tcp -s $INTERNAL_NET -o $INTERNET_IF -j SNAT --to-source $INTERNET_IP
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -p tcp --dport 53 -j ACCEPT
### HTTP, HTTPS and SSH connections
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -p tcp -m multiport --dports 80,443,22 -j ACCEPT
### FTP connections (in passive and active modes) to external FTP servers
iptables -A FORWARD -i $INTERNAL_IF -o $INTERNET_IF -p tcp --dport 21 -j ACCEPT

# Suricata
## Configure Suricata to analyze all traffic received and sent by the router system
iptables -I INPUT 1 -j NFQUEUE --queue-num 0
iptables -I OUTPUT 1 -j NFQUEUE --queue-num 0
iptables -I FORWARD 1 -j NFQUEUE --queue-num 0

# Drop all other traffic
iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP


## Copies the suricata.yaml no suricata.yaml default location
cp suricata.yaml /etc/suricata/suricata.yaml
## This is the additional rules file made to ensure XSS, SQLi and port scanning is detected and blocked
cp local.rules /var/lib/suricata/rules/local.rules

## This downloads the current Emerging Threats Open ruleset into suricata.rules file
suricata-update

## Run suricata in IDS mode, with NFQUEUE as the capture method, and with the highest level of verbosity ( -vvvv)
suricata -c /etc/suricata/suricata.yaml -vvvv -q 0
