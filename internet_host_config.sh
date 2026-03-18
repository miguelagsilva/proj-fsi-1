# Set up interface
ifconfig enp0s8 193.136.0.1 netmask 255.255.0.0 up
ip route add default via 193.136.0.254

# Clear Iptables
iptables -F
iptables -X

