#!/bin/bash

#### Lab 5 ####
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
##Checking running script by root###
if [ `id -u` -ne 0 ]
then
	echo "Must run this script by root" >&2
	exit 1 
fi

read -p "What is your Seneca username: " username
read -p "What is your FULL NAME: " fullname
read -p "What is your IP Address of VM1: " IP1
read -p "What is your IP Address of VM2: " IP2
digit=$( echo "$IP" | awk -F. '{print $3}' )

#### Checking Internet Connection of HOST###
echo "Checking Internet Connection"
check "ping -c 3 google.ca > /dev/null" "Can not ping GOOGLE.CA, check your Internet connection "


###--- Checking if can ssh to VM2
echo "-------Checking SSH Connection---------"
check "ssh -o ConnectTimeout=5 root@$IP2 ls > /dev/null" "Can not SSH to VM2, fix the problem and run the script again "

###--- Checking VM2 can ping google.ca 
echo "-------Pinging GOOGLE.CA from VM2---------"
check "ssh root@$IP2 ping -c 3 google.ca > /dev/null" "Can not ping GOOGLE.CA from VM2, check INTERNET connection then run the script again"

## Installing Samba Package ######
echo 
echo "############ Installing Samba Server ###########"
echo 
check "ssh $IP2 yum install samba* -y" "Can not use Yum to install"
ssh $IP2 systemctl start smb
ssh $IP2 systemctl enable smb
echo -e "\e[32mInstalling Done\e[m"


### Backup config file ###

echo "Backing up configuration file"
if [ ssh $IP2 ! -f /etc/samba/smb.conf.backup ]
then
	ssh $IP2 "cp /etc/samba/smb.conf /etc/samba/smb.conf.backup"
done
echo -e "\e[32mBacking up Done\e[m"

cat > smb.conf << EOF

[global]
workgroup = WORKGROUP 
server string = $fullname
encrypt passwords = yes
smb passwd file = /etc/samba/smbpasswd
  
[home]
comment = $fullname
path = /home/<yourSenecaID>
public = no
writable = yes
printable = no
create mask = 0765

[homes]
comment = automatic home share
public = no
writable = yes
printable = no
create mask = 0765
browseable = no

EOF
check "scp smb.conf $IP2:/etc/samba/smb.conf " "Error when trying to copy SMB.CONF"
rm -rf smb.conf