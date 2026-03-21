#!/bin/bash
# Internet 

# Set up the network interface with the appropriate IP address and netmask
# enp0s8 corresponds to the Network Adapter 2 in VirtualBox, which is connected to the Internet network
ifconfig enp0s8 193.136.212.1 netmask 255.255.0.0 up
ip route add default via 193.136.0.254

# Clear Iptables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Disable firewall
systemctl stop firewalld
systemctl disable firewalld
