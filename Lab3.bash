#!/bin/bash

##### Lab 3 ###########
function check() {
	if eval $1
	then
		echo -e "\e[32mOKAY_Babe. Good job \e[0m"
	else
		echo
     		echo
     		echo -e "\e[0;31mWARNING\e[m"
     		echo
     		echo
     		echo $2
     		echo
     		exit 1
	fi	
}
virsh start vm1 > /dev/null 2>&1
virsh start vm2 > /dev/null 2>&1
virsh start vm3 > /dev/null 2>&1
list_vms="vm1 vm2 vm3"
read -p "What is your Seneca username: " username
read -p "What is your IP Address of VM1: " IP
digit=$( echo "$IP" | awk -F. '{print $3}' )
domain=$username.ops

##Checking running script by root###
if [ `id -u` -ne 0 ]
then
	echo "Must run this script by root" >&2
	exit 1 
fi

#### Checking Internet Connection###
check "ping -c 3 google.ca > /dev/null" "Can not ping GOOGLE.CA, check your Internet connection "

## Installing BIND Package ######
echo 
echo "############ Installing DNS ###########"
echo 
check "yum install bind* -y" "Can not use Yum to install"
systemctl start named
systemctl enable named
echo -e "\e[32mInstalling Done\e[m"

### Making DNS configuration file ####
cat > /etc/named.conf << EOF
options {
        directory "/var/named/";
        allow-query {127.0.0.1; 192.168.$digit.0/24;};
        forwarders { 192.168.40.2; };
};
zone "." IN {
	type hint;
        file "named.ca";
};
zone "localhost" {
        type master;
        file "named.localhost";
};
zone "$username.ops" {
        type master;
        file "mydb-for-$username-ops";
};
zone "$digit.168.192.in-addr.arpa." {
        type master;
        file "mydb-for-192.168.$digit";
};
EOF

##### Making forward zone file ####

cat > /var/named/mydb-for-$username-ops << EOF
\$TTL    3D
@       IN      SOA     host.$username.ops.      hostmaster.$username.ops.(
                2018042901       ; Serial
                8H      ; Refresh
                2H      ; Retry
                1W      ; Expire
                1D      ; Negative Cache TTL
);
@       IN      NS      host.$username.ops.
host    IN      A       192.168.$digit.1
vm1		IN		A 		192.168.$digit.2
vm2		IN		A 		192.168.$digit.3
vm3		IN		A 		192.168.$digit.4

EOF

##### Making reverse zone file  #####

cat > /var/named/mydb-for-192.168.$digit << EOF

\$TTL    3D
@       IN      SOA     host.$username.ops.      hostmaster.$username.ops.(
                2018042901       ; Serial
                8H      ; Refresh
                2H      ; Retry
                1W      ; Expire
                1D      ; Negative Cache TTL
);
@       IN      NS      host.$username.ops.
1       IN      PTR     host.$username.ops.
2		IN		PTR		vm1.$username.ops.
3		IN		PTR		vm2.$username.ops.
4		IN		PTR		vm3.$username.ops.

EOF
	
echo	
echo -e "###\e[32mFiles Added Done\e[m###"
echo
#### Adding DNS and DOMAIN ####
systemctl stop NetworkManager
systemctl disable NetworkManager

if [ ! -f /etc/sysconfig/network-scripts/ifcfg-ens33.backup ]
then
	cp /etc/sysconfig/network-scripts/ifcfg-ens33 /etc/sysconfig/network-scripts/ifcfg-ens33.backup
fi
grep -v -i -e "^DNS.*" -e "^DOMAIN.*" /etc/sysconfig/network-scripts/ifcfg-ens33 > ipconf.txt
scp ipconf.txt /etc/sysconfig/network-scripts/ifcfg-ens33
echo "DNS1=192.168.$digit.1" >> /etc/sysconfig/network-scripts/ifcfg-ens33
echo "DOMAIN=$username.ops" >> /etc/sysconfig/network-scripts/ifcfg-ens33
echo host.$domain > /etc/hostname
rm -rf ipconf.txt

#### Adding rules in IPtables ####
grep -v ".*INPUT.*dport 53.*" /etc/sysconfig/iptables > iptables.txt
scp iptables.txt /etc/sysconfig/iptables
iptables -I INPUT -p tcp --dport 53 -j ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables-save > /etc/sysconfig/iptables
service iptables save
rm -rf iptables.txt

### Remove hosts in the previous lab ###
grep -v -i -e "vm.*" /etc/hosts > host.txt
scp host.txt /etc/hosts
echo "search $domain" > /etc/resolv.conf
echo "nameserver 192.168.${digit}.1" >> /etc/resolv.conf


systemctl restart iptables
systemctl restart named


clear
echo	
echo -e "###\e[32mConfiguration Done\e[m###"
echo

### CONFIG USERNAME, HOSTNAME, DOMAIN VM1,2,3
for (( i=2;i<=4;i++ ))
do
intvm=$( ssh 192.168.$digit.${i} '( ip ad | grep -B 2 192.168.$digit | head -1 | cut -d" " -f2 | cut -d: -f1 )' )
ssh 192.168.$digit.${i} "echo vm$(($i-1)).$domain > /etc/hostname"
check "ssh 192.168.$digit.${i} grep -v -e '^DNS.*' -e 'DOMAIN.*' /etc/sysconfig/network-scripts/ifcfg-$intvm > ipconf.txt" "File or directory not exist"
echo "DNS1="192.168.$digit.1"" >> ipconf.txt
echo "PEERDNS=no" >> ipconf.txt
echo "DOMAIN=$domain" >> ipconf.txt
check "scp ipconf.txt 192.168.$digit.${i}:/etc/sysconfig/network-scripts/ifcfg-$intvm > /dev/null" "Can not copy ipconf to VM${i}"
rm -rf ipconf.txt > /dev/null
ssh 192.168.$digit.${i} "echo "search $domain" > /etc/resolv.conf"
ssh 192.168.$digit.${i} "echo "nameserver 192.168.${digit}.1" >> /etc/resolv.conf"
done







