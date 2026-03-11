#!/bin/bash

EXTERNAL_IF="enp0s10"

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

# Drop all other traffic
iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP
iptables -A OUTPUT -j DROP
