# Set up interface
ifconfig enp0s8 193.137.16.75 netmask 0.0.0.0 up
ip route add default via 87.248.214.97  

# Clear Iptables
iptables -F
iptables -X

