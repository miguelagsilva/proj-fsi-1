#!/bin/bash

EXTERNAL_IF="enp0s10"

INTERNAL_NET="192.168.10.0/24"
INTERNAL_IF="enp0s9"
INTERNAL_FTP_SERVER="192.168.10.2"
INTERNAL_DATASTORE_SERVER="192.168.10.3"

DMZ_IF="enp0s8"
DMZ_NET="23.214.219.128/25"
DMZ_SMTP_SERVER="23.214.219.129"
DMZ_DNS_SERVER="23.214.219.130"
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
iptables -A FORWARD -d $DNS_IP -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s $DNS_IP -p udp --sport 53 -j ACCEPT

# Drop all other traffic
iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP
iptables -A OUTPUT -j DROP
