# Set up interface
ifconfig enp0s8 192.168.10.2 netmask 255.255.255.0 up
ip route add default via 192.168.10.254

# Clear Iptables
iptables -F
iptables -X

