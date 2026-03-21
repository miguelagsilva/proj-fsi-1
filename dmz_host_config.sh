#!/bin/bash
# DMZ

# Set up the network interface with the appropriate IP address and netmask
# enp0s8 corresponds to the Network Adapter 2 in VirtualBox, which is connected to the DMZ network
ifconfig enp0s8 23.214.219.132 netmask 255.255.255.128 up
ip route add default via 23.214.219.254

# Clear iptables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Disable firewall
systemctl stop firewalld
systemctl disable firewalld
