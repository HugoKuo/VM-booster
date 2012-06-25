#!/bin/bash 

echo "Notice : Please make sure mac addresses have been stored"
#echo "1-Add PMs into database - python bootstrap.pyc rack -a 1 mac/xxxxxx"
#echo "2-Add VMs into database - python bootstrap.pyc vm -a"
#echo "3-Configure hostname    - python bootstrap.pyc modify -n {exist_hostname} -f hostname -v {new_hostname}"
#echo "4-Create PXE tftp files - python bootstrap.pyc boot -a"
echo
echo "**********  Ready to run deploy progress  **********"
echo
read -p "Are you sure to continue(y/n) : " key1

if [ "$key1" == "n" ] || [ "$key1" == "N" ]; then
	echo	
	echo	
	echo "!!!!!!! STOP !!!!!!!"
	echo
	exit
fi
if [ "$key1" == "y" ] || [ "$key1" == "Y" ]; then
	echo "	Run into VM installation progress	"
fi
  
time_start=`date`

#Backup xml
sleep 1

#1.Create tmpiso tmpvm tmptrans
mkdir /mnt/tmploop /mnt/tmptrans /mnt/tmpiso

#2.mount 15G tmpfs to /tmploop 
mount tmpfs /mnt/tmploop -t tmpfs -o size=15G

#3.Create two loop devices & Create EXT4 FS
cd /mnt/tmploop ; dd if=/dev/zero of=1G.img bs=1M count=1024 ; dd if=/dev/zero of=12G.img bs=1M count=12288
mkfs.ext4 -F /mnt/tmploop/1G.img  
mkfs.ext4 -F /mnt/tmploop/12G.img

#4.mount loop devices to tmperarily folder
mount /mnt/tmploop/1G.img /mnt/tmpiso 
mount /mnt/tmploop/12G.img /mnt/tmptrans

#5.copy necessary files
cp /opt/cloudena/cloudena_boot/share/ISO/* /mnt/tmpiso
cp -r /opt/cloudena/cloudena_boot/vms/* /mnt/tmptrans

#6.disable VM HA
#service XXXXXX stop

#7.Umount and remount to target
umount -l /mnt/tmpiso 
umount -l /mnt/tmptrans
mount /mnt/tmploop/1G.img /opt/cloudena/cloudena_boot/share/ISO
mount /mnt/tmploop/12G.img /opt/cloudena/cloudena_boot/vms
sleep 1
echo
echo

#Change to cloudenaBoot folder
cd /opt/cloudena/cloudena_boot/


echo "To add PMs into DB"
echo
echo "**** Exist mac file list ****"
ls mac/
echo
read -p "Which mac address file would you like?" macfile
rackid=${macfile#${macfile%?}}
python bootstrap.pyc rack -a $rackid mac/$macfile
sleep 1 
echo

echo "To add VMs into DB"
python bootstrap.pyc vm -a

echo
read -p "Would you like to customize hostname(y/n): " key3
if [ "$key3" == "n" ] || [ "$key3" == "N" ]; then
	echo
fi
if [ "$key3" == "y" ] || [ "$key3" == "Y" ]; then
    for (( ; ; ))
        do
        python bootstrap.pyc node -l | cut -d "|" -f 2,10 | sed -e 1,3d -e \$d
        echo
        read -p "Original hostname , enter [ok] to leave : " org_name
        if [ "$org_name" == "ok" ];then
            echo            
            break
        else
            read -p "New hostname : " new_name
        fi
        python bootstrap.pyc modify -n $org_name -f hostname -v $new_name
    done    	
fi

echo
echo "To Create TFTP PXE cfg for all servers"
python bootstrap.pyc boot -a
cd -

#Boot VMs
echo "	Boot up VMs	, Please boot up PMs manually"
for (( ; ; ))
    do
    read -p "Does all PMs restart and power on now (y/n)? " key2
    if [ "$key2" == "n" ] || [ "$key2" == "N" ]; then
	    echo	
	    echo "Wait For PMs restart and power on"
	    echo
	    
    elif [ "$key2" == "y" ] || [ "$key2" == "Y" ]; then
        echo "	Run into installation progress	"
        break
    fi
done

cd /opt/cloudena/cloudena_boot/
python bootstrap.pyc vm -p
sleep 2
for (( ; ; ))
	do  
    echo
    echo
	echo "To Check OS installation progress , please press  [ENTER] "
	echo "To Check connectivity	, please insert [c]"
    echo "To run Puppet Progress , check role assignment first , please insert [puppet] "
	echo "To Check role table and assign role , please insert [role]"
	read -p " Operation : " key 
	if [ "$key" == "c" ] || [ "$key" == "C" ]; then
		python monitor.pyc 
		sleep 1
	elif [ "$key" == "role" ]; then
        python bootstrap.pyc role -l
        read -p "would you like to assign role now (y/n)?" role_key
        if [ "$role_key" == "n" ] || [ "$role_key" == "N" ]; then
            echo        	
        fi
        if [ "$role_key" == "y" ] || [ "$role_key" == "Y" ]; then
        	read -p "Which hostname(FQDN) would you like to assign role?" org_hostname
            read -p "Insert role name: " new_role
            #python bootstrap.pyc modify -n $org_hostname -f hostname -v $new_hostname
            python bootstrap.pyc role -n $org_hostname -r $new_role
        fi        
	elif [ "$key" == "puppet" ]; then
		echo "Execute bootstrap puppet -a"
		break
	else
		echo "Current Installation Status"
        python bootstrap.pyc node -l
        echo
        echo
		python bootstrap.pyc os -l
		sleep 1
	fi  
done
sleep 1
echo "Configuring conf/zone_N.conf "
sleep 1
python bootstrap.pyc puppet -c 1
echo
echo
echo "Execute bootstrap puppet -a"
echo
sleep 1
python bootstrap.pyc puppet -a
sleep 2
for (( ; ; ))
	do
	echo "To Check Status of service installation , please press [Enter] "
	echo "To finish the rest progress , please insert [finish] "
	read -p "Option: " key
	echo $key
	if [ "$key" == "finish" ]; then
		echo "Ready to clone VMs back to FS"
		break
    else 
		python bootstrap.pyc role -l
	fi
done

sleep 1
echo "===== Shutoff VMs ====="
virsh destroy BACKUP
sleep 1
virsh destroy KEYSTONE             
sleep 1
virsh destroy MONITOR             
sleep 1
virsh destroy POLICY_SERVER      
sleep 1
virsh destroy PORTAL 
sleep 1

echo "===== Migrate VMs ====="

umount -l /opt/cloudena/cloudena_boot/vms
mount /mnt/tmploop/12G.img /mnt/tmptrans
cp -r /mnt/tmptrans/* /opt/cloudena/cloudena_boot/vms

#umount -l /opt/cloudena/cloudena_boot/share/ISO
umount -l /mnt/tmptrans

#umount -l 
cd /opt/cloudena/cloudena_boot/
python bootstrap.pyc vm -p

sleep 3

#umount all ramdisks
umount -l /opt/cloudena/cloudena_boot/share/ISO
umount -l /mnt/tmploop


time_end=`date`
echo "=================Done=================" 
echo "Start @ " $time_start
echo "End   @ " $time_end
echo "=================Done================="

