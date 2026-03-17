ifconfig enp0s8 192.168.10.254 netmask 255.255.255.0 up
ifconfig enp0s9 23.214.219.254 netmask 255.255.255.128 up

INTERNAL_FTP_SERVER="192.168.10.2"
INTERNAL_DATASTORE_SERVER="192.168.10.3"
INTERNET_EDEN="193.136.212.1"
INTERNET_DNS2="193.137.16.75"
EXTERNAL_IP="87.248.214.97"



iptables -t nat -A PREROUTING -p tcp -s $INTERNET_EDEN -d $EXTERNAL_IP --dport 22 -j DNAT --to-destination $INTERNAL_DATASTORE_SERVER
iptables -t nat -A PREROUTING -p tcp -s $INTERNET_DNS2 -d $EXTERNAL_IP --dport 22 -j DNAT --to-destination $INTERNAL_DATASTORE_SERVER

iptables -A FORWARD -p tcp -s $INTERNET_EDEN -d $INTERNAL_DATASTORE_SERVER --dport 22 -j ACCEPT
iptables -A FORWARD -p tcp -s $INTERNET_DNS2 -d $INTERNAL_DATASTORE_SERVER --dport 22 -j ACCEPT


# Adicionar FTP com porta 20 e 21 perguntar ao stor pq high port?