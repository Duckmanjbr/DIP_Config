#!/bin/bash
#
#Info
#=======================
#	File: DIP_config_generator.sh
#	Name: Create DIP Configurations
#
	VERSION_NUM='3.2'
# 	*Version is major.minor format
# 	*Major is updated when new capability is added
# 	*Minor is updated on fixes and improvements
#
#History
#=======================		
#	20Jun2017 v1.0 
#		Dread Pirate
#		*Created from starter script designed by 836 to auto create firewall scripts
#
# 	29Jun2017 v1.1
#		Dread Pirate
#		*Changed to variable format to allow ease of different base files
#
#       4Jul2017 v2.0
#		Dread Pirate
#		*HAPPY B-DAY USA!  MERICA!
#		*Got really bored.  Added ESXi network backup/restore functionality.
#		*Added full menu system 
#
#	11Jul2017 v3.0
#		Dread Pirate
#		*Incorporated switch config creation to start streamlining the process. 
#
#	22Nov2017 v3.1
#		Dread Pirate
#		*Added squadron variables for ease of use between multiple sqds.
#		*Other small bug fixes
#
#	29Nov2017 v3.2
#		Dread Pirate
#		*Minor bug fixes for name in switch config 
#		*Error checking added for ESXi config
#	
#
#Description 
#=======================
# This script changes the IPs/VLANs of the baseline files to allow dynamic build-out of multiple configuration files for each different kit.
# This will allow two Sqds (18 kits) to use the same backbone infrastructure in parallel while maintaining kit isolation by VLAN.
#
#Notes
#=======================
# https://github.com/Duckmanjbr/DIP_Config/blob/master/DIP_config_generator.sh
#
#####################################################
#Selectable Variables (user selected)
SQD1='3'					### Single digit number for Sqd identifier.  Ex: 833="3", 834="4", etc.  Only use one number!
SQD1NAME='Ravens'				### Sqd 1 name.
SQD2='6'					### Single digit number for Sqd identifier.  Ex: 833="3", 834="4", etc.  Only use one number!
SQD2NAME='Warriors'				### Sqd 2 name.
#
#Base files will be stored in a parent folder labeled ESXi,Firewall,Switch,etc
#Newly created configuration files will be created in a folder with the name of the kit configs created.  Ex: "Kit_5"
FIRE_BASE_FILE='firewall.base.xml'              ### Baseline file to create all others from
FIRE_FILE='firewall'                            ### Name of config file to create
PFSENSE_BACKUP="config-firewall.dmss-2"         ### Name of the backup file as exported from pfSense
ESX_BASE_FILE='esx.base.conf'                   ### Baseline file to create all others from
ESX_FILE='esx.conf'                             ### Name of config file to create
SWITCH_BASE_FILE='Switch_101.master'            ### Baseline file to create all others from
#
#####################################################
#Script Variables
KIT=''                                          ### Kit number (1-18)
FILE=''                                         ### File being adjusted
IP=''                                           ### IP octet of kit (101, 102, 103, etc)
OPTION=''                                       ### Prompted question options
CASESQD1=(${SQD1}{A,B,C}{1,2,3}A)               ### This Array contains the DIP cases for the SQD1 switch names eg 3A1A, 3C2A, etc.
CASESQD2=(${SQD2}{A,B,C}{1,2,3}A)               ### This Array contains the DIP cases for the SQD2 switch names eg 6A1A, 6C2A, etc.
CASENAME=("${CASESQD1[@]}" "${CASESQD2[@]}")    ### Array merge
CASE=''                                         ### The Case name based from the kit number and the array.
TUNNEL_IP_SOURCE=''                             ### Tunnel IPs
TUNNEL_IP_DEST=''                               ### Tunnel IPs

#####################################################
#Functions:
#
#Check for running script as root
Checkroot()
{
        if [ `whoami` != "root" ]; then
                echo "This Script must be run as root"
                sleep 1
                exit
        fi
}
#=======================
#
#
Header()
{
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "+                                                                      +"
	echo "+                  DIP Configuration Setup Script $VERSION_NUM                  +"
	echo "+                                                                      +"
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "+                                                                      +"

}
#=======================
Footer()
{
	echo "+                                                                      +"
	echo "+                                                                      +"
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo ""
}
#=======================
Mainmenu()
{
	clear
Header
	echo "+        [ 1 ] Create ESXi config for single kit                       +"
	echo "+                                                                      +"
	echo "+        [ 2 ] Create Firewall config for single kit                   +"
	echo "+                                                                      +"
	echo "+        [ 3 ] Create new switch config from master file               +"
	echo "+                                                                      +"
	echo "+                                                                      +"
	echo "+      **[ F ] Fast Setup Configuration (Firewall,ESXi,Switch)**       +"
	echo "+                                                                      +"
	echo "+                                                                      +"
	echo "+        [ X ] Exit Script                                             +"
	echo "+                                                                      +"
	echo "+                                                                      +"
	echo "+        [ 4 ] Create new firewall.base.xml from pfSense backup file   +"
	echo "+        [ 5 ] Create new esx.base.conf from backup file               +"
Footer
	read -p "Please make a Selection: " mainmenu_option
	case $mainmenu_option in
		1) clear && File_check BE && Kits && Create_esx-config && Continue && Mainmenu;;
		2) clear && File_check BF && Kits && Create_fire-config && Continue && Mainmenu;; 
		3) clear && File_check S && Kits && Create_switch_config && Continue && Mainmenu;;
		4) clear && File_check PB && Create_fire-base_file && Mainmenu;;
		5) clear && File_check E && Create_esx-base_file && Mainmenu;;
		f|F) clear && File_check BE && File_check BF && File_check S && Kits && Create_switch_config && Create_fire-config && Create_esx-config && Continue && Mainmenu;;
		x|X) clear && exit ;;
		*) echo "Invalid input" && sleep 1 && Mainmenu;;
	esac
}
#=======================
Kits()
{
Header
	echo "+        Kit numbers are designed and configured per flight            +"
	echo "+    This number schema repeats throughout the kits and networks       +"
	echo "+                                                                      +"
	echo "+                                                                      +"
	echo "+                 ============ $SQD1NAME =============                    +"
	echo "+              DOA              DOB                DOC                 +"
	echo "+          ${SQD1}A1x   101       ${SQD1}B1x   104         ${SQD1}C1x   107              +"
	echo "+          ${SQD1}A2x   102       ${SQD1}B2x   105         ${SQD1}C2x   108              +"
	echo "+          ${SQD1}A3x   103       ${SQD1}B3x   106         ${SQD1}C3x   109              +"
	echo "+                                                                      +"
	echo "+                                                                      +"
	echo "+                 =========== $SQD2NAME ============                    +"
	echo "+              DOA              DOB                DOC                 +"
	echo "+          ${SQD2}A1x   110       ${SQD2}B1x   113         ${SQD2}C1x   116              +"
	echo "+          ${SQD2}A2x   111       ${SQD2}B2x   114         ${SQD2}C2x   117              +"
	echo "+          ${SQD2}A3x   112       ${SQD2}B3x   115         ${SQD2}C3x   118              +"
Footer
#
read -p "What kit number are you configuring? [ex: 101,105,116,etc]  " IP
read -p "You selected Kit ${IP}. Is this correct? [y/n]  " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]];then
	KIT="$(($IP - 100))"
	CASE="${CASENAME[$(($KIT - 1))]}"
#test	echo ""
#test	echo " ${CASESQD1[*]} "
#test	echo " ${CASESQD2[*]} "
#test	echo " All Casses= ${CASENAME[*]} "
#test	echo " CASE= ${CASE} "
else
	clear
	Kits
fi
}
#=======================
File_check()
{
#Check for existence of baseline files
echo "Checking for files…"
if [ $1 = 'E' ];then
	FILE=$ESX_FILE
elif [ $1 = 'F' ];then
	FILE=$FIRE_FILE
elif [ $1 = 'BF' ];then
	FILE=Firewall/$FIRE_BASE_FILE
elif [ $1 = 'BE' ];then
	FILE=ESXi/$ESX_BASE_FILE
elif [ $1 = 'PB' ];then
	if ls ${PFSENSE_BACKUP}* >/dev/null 2>&1; then
		FILE=${PFSENSE_BACKUP}
	fi
elif [ $1 = 'S' ];then
	FILE=Switch/${SWITCH_BASE_FILE}
elif [ -z $1 ];then
	echo "There was an error on file checking. Argument is empty."
	sleep 1
	exit
else 
	echo "There was an error....  The option seen was ($1)"
fi
echo "File being checked:  $FILE"
sleep 1
if [[ ! -e $FILE ]] && [[ ! $FILE = $PFSENSE_BACKUP ]];then
	echo "[-] $FILE file is missing!!!  It must be in your current directory or in its appropriate folder. "
	sleep 3
	exit
fi
clear
}
#=======================
Create_esx-config()
{
#Create esx.conf file for each different kit.
#
#Full server backup/restore can be done from cmdline.
#Backup:
# vim-cmd hostsvc/firmware/backup_config 
#saved in: /scratch/downloads
#Restore:
# vim-cmd hostsvc/maintenance_mode_enter
# vim-cmd hostsvc/firmware/restore_config 1 /tmp/configBundle.tgz
read -p "Are you setting up primary ESXi or secondary? (p/s)  " -n 1 -r
if [[ $REPLY =~ ^[Pp]$ ]];then
	mkdir -p Kit_${KIT}
	sed -r "s/10\.101\./10\.${IP}\./g" ESXi/$ESX_BASE_FILE > Kit_${KIT}/$ESX_FILE
elif [[ $REPLY =~ ^[Ss]$ ]];then
        mkdir -p Kit_${KIT}
	sed -r "s/10\.101\.32\.2/10\.${IP}\.32\.4/g" ESXi/$ESX_BASE_FILE > Kit_${KIT}/$ESX_FILE
else 
	Create_esx-config
fi
sed -i "s/132/${KIT}32/g" Kit_${KIT}/$ESX_FILE  ### Corrects the Management VLAN
sed -i "s/134/${KIT}34/g" Kit_${KIT}/$ESX_FILE  ### Corrects the VoIP VLAN
sed -i "s/135/${KIT}35/g" Kit_${KIT}/$ESX_FILE  ### Corrects the Internal VLAN
sed -i "s/136/${KIT}36/g" Kit_${KIT}/$ESX_FILE  ### Corrects the External VLAN
sed -i "s/137/${KIT}37/g" Kit_${KIT}/$ESX_FILE  ### Corrects the DMZ VLAN
echo '' 
echo '[+] Generated esx.conf'
echo ''
echo 'This new esx.conf file must be copied into the server.  '
echo 'Enable SSH in Host->Actions->Service w/in the webgui. '
echo 'Also turn on Maintenance Mode in Host->Actions '
echo ''
echo 'From MIP: scp esx.conf user@<IP>://etc/vmware/ '
echo 'Reboot the server.      '
}
#=======================
Create_fire-config()
{
# Create new config based off baseline file
mkdir -p Kit_${KIT}
sed -r s/10\.101\./10\.${IP}\./g Firewall/${FIRE_BASE_FILE} > Kit_${KIT}/${FIRE_FILE}.${IP}.xml
echo "[+] Generated ${FIRE_FILE}.${IP}.xml"
}
#=======================
Create_esx-base_file()
{
#Create a baseline file from a esx.conf
sed -r "s/10\.1([0,1][0-8])\.32\.[2,4]/10\.101\.32\.2/g" $ESX_FILE > $ESX_BASE_FILE
sed -ri "s/10\.1([0,1][0-8])\./10\.101\./g" $ESX_BASE_FILE
sed -i "s/vlanId\s=\s\"*[0-8]32\"/vlanId = \"132\"/g" $ESX_BASE_FILE  ### Corrects the Management VLAN
sed -i "s/vlanId\s=\s\"*[0-8]34\"/vlanId = \"134\"/g" $ESX_BASE_FILE  ### Corrects the VoIP VLAN
sed -i "s/vlanId\s=\s\"*[0-8]35\"/vlanId = \"135\"/g" $ESX_BASE_FILE  ### Corrects the Internal VLAN
sed -i "s/vlanId\s=\s\"*[0-8]36\"/vlanId = \"136\"/g" $ESX_BASE_FILE  ### Corrects the External VLAN
sed -i "s/vlanId\s=\s\"*[0-8]37\"/vlanId = \"137\"/g" $ESX_BASE_FILE  ### Corrects the DMZ VLAN
chown -f assessor $ESX_BASE_FILE
echo "[+] Generated $ESX_BASE_FILE"
Continue
}
#=======================
Create_fire-base_file()
{
#Create baseline file from pfSense backup .xml file.
sed -r "s/10\.1([0,1][0-8])\./10\.101\./g" ${PFSENSE_BACKUP}* > $FIRE_BASE_FILE
sed -i "s/10\.101\.32\.3/10\.101\.32\.1/g" $FIRE_BASE_FILE  ### Corrects the Management VLAN
sed -i "s/10\.101\.34\.3/10\.101\.34\.1/g" $FIRE_BASE_FILE  ### Corrects the VoIP VLAN
sed -i "s/10\.101\.35\.3/10\.101\.35\.1/g" $FIRE_BASE_FILE  ### Corrects the Internal VLAN
sed -i "s/10\.101\.36\.3/10\.101\.36\.1/g" $FIRE_BASE_FILE  ### Corrects the External VLAN
sed -i "s/10\.101\.37\.3/10\.101\.37\.1/g" $FIRE_BASE_FILE  ### Corrects the DMZ VLAN
#sed -i '/<openvpn>/,/<\/openvpn>/{/<openvpn>/!{/\/openvpn>/!d}}' $FIRE_BASE_FILE
chown -f assessor $FIRE_BASE_FILE
echo "[+] Generated $FIRE_BASE_FILE"
Continue
}
#
#=======================
Continue()
{
echo ''
echo ''
chown -Rf assessor Kit_${KIT}
read -p '[Press Enter to continue] '
}
#
#=======================
Tunnel_Config() 
{
#Needs work if needed at all?
sed -i 's/interface Tunnel.*/interface Tunnel'"${KIT}"'/g' Kit_${KIT}/Switch_${IP}
sed -i 's/ip address 10\.10\.10\..* 255\.255\.255\.252/ip address 10\.10\.10\.'"$TUNNEL_IP_SOURCE"' 255.255.255.252/g' Kit_${KIT}/Switch_${IP}
sed -i 's/tunnel destination 10\.10\.10\..*/tunnel destination 10\.10\.10\.'"$TUNNEL_IP_DEST"'/g' Kit_${KIT}/Switch_${IP}
}
#
#=======================
Create_switch_config()
{
mkdir -p Kit_${KIT}	
cp Switch/$SWITCH_BASE_FILE Kit_${KIT}/Switch_${IP}
sed -i "s/10\.101/10\.${IP}/g" Kit_${KIT}/Switch_${IP}
echo ''
sed -i "s/DIP_101_.*/DIP_${IP}_${CASE}/g" Kit_${KIT}/Switch_${IP} ###Sets hostname by IP/DIP case.
sed -i "s/132/"${KIT}"32/g" Kit_${KIT}/Switch_${IP} ###This replaces VLAN 132 with the appropriate switch VLAN.		
sed -i "s/134/"${KIT}"34/g" Kit_${KIT}/Switch_${IP} ###This replaces VLAN 134 with the appropriate switch VLAN.
sed -i "s/135/"${KIT}"35/g" Kit_${KIT}/Switch_${IP} ###This replaces VLAN 135 with the appropriate switch VLAN.		
sed -i "s/136/"${KIT}"36/g" Kit_${KIT}/Switch_${IP} ###This replaces VLAN 136 with the appropriate switch VLAN.		
sed -i "s/137/"${KIT}"37/g" Kit_${KIT}/Switch_${IP} ###This replaces VLAN 137 with the appropriate switch VLAN.
#TUNNEL_IP_SOURCE=$(expr 4 \* ${IP} - 2)
#TUNNEL_IP_DEST=$(expr $TUNNEL_IP_SOURCE - 1)
#Tunnel_Config
echo ''
echo "[+] Generated Switch_${IP}"
}
#
####################################################
#Run script:
#
#
Checkroot
Mainmenu
