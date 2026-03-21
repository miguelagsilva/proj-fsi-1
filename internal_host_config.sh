#!/bin/bash
# Internal

# Set up the network interface with the appropriate IP address and netmask
# enp0s8 corresponds to the Network Adapter 2 in VirtualBox, which is connected to the Internal network
ifconfig enp0s8 192.168.10.2 netmask 255.255.255.0 up
ip route add default via 192.168.10.254

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
