#!/bin/sh
 
############################################################
################# Application Center start #################
############################################################

write_application_center_master () {
   cat >> /tmp/application_center_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh
HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
PORT=\$2

echo "Installing Application Center" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 PORT: \${PORT}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Installing mariadb" | tee -a \${LOG}
for PKG in mariadb-common-10.3.39-1.module_el8.8.0%2B3609%2B204d4ab0.x86_64.rpm \
   mariadb-10.3.39-1.module_el8.8.0%2B3609%2B204d4ab0.x86_64.rpm \
   mariadb-errmsg-10.3.39-1.module_el8.8.0%2B3609%2B204d4ab0.x86_64.rpm \
   mariadb-server-10.3.39-1.module_el8.8.0%2B3609%2B204d4ab0.x86_64.rpm
do
   yum -y --nogpgcheck install https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/Packages/\${PKG} >> \${LOG} 2>&1
   done

echo "Downloading PAC tarballs from box" | tee -a \${LOG}
cd /tmp
echo "   pac10.2.0.13_standard_linux-x64.tar.Z" | tee -a \${LOG}
curl -Lo pac10.2.0.13_standard_linux-x64.tar.Z https://ibm.box.com/shared/static/c5qflv3zho6cdrmadrevzpezfkk9hnu7.z >> \${LOG} 2>&1
echo "   mysql-connector-java-5.1.25-3.el7.noarch.rpm" | tee -a \${LOG}
curl -Lo mysql-connector-java-5.1.25-3.el7.noarch.rpm https://ibm.box.com/shared/static/r1l2g0iaq1n6geoam551ipo22wsvum98.rpm >> \${LOG} 2>&1
rpm -i --nodeps --force --nosignature mysql-connector-java-5.1.25-3.el7.noarch.rpm >> \${LOG} 2>&1
systemctl enable mariadb >> \${LOG} 2>&1
systemctl start mariadb >> \${LOG} 2>&1
tar xzf pac10.2.0.13_standard_linux-x64.tar.Z >> \${LOG} 2>&1
cd pac10.2.0.13_standard_linux-x64
export MYSQL_JDBC_DRIVER_JAR="/usr/share/java/mysql-connector-java.jar"
sed -i -e s/"https"/"http"/g -e s/"read -s passwd"/""/g -e s/"read answer"/"answer=y"/g pacinstall.sh

. \${LSF_TOP}/conf/profile.lsf

LSF_TOP=\$1

chmod 755 pacinstall.sh
./pacinstall.sh -y >> \${LOG} 2>&1
sed -i s/"-Ddefault.novnc.port=6080"/"#-Ddefault.novnc.port=6080"/g /opt/ibm/lsfsuite/ext/gui/conf/jvm.options
sed -i s/"innodb_buffer_pool_size = 3072M"/"innodb_buffer_pool_size = 128M"/g /etc/my.cnf
systemctl restart  mariadb.service >> \${LOG} 2>&1
   cat >> /opt/ibm/lsfsuite/ext/gui/3.0/bin/ac_daemons <<EOF2
#!/bin/bash
source /opt/ibm/lsfsuite/ext/profile.platform
OP=\\\$1
if [ "x\\\${OP}" = "x" ]; then
    exit 1
fi
perfadmin \\\${OP} all
pmcadmin \\\${OP}
exit 0
EOF2
chmod 755 /opt/ibm/lsfsuite/ext/gui/3.0/bin/ac_daemons

cat >> /etc/systemd/system/acd.service <<EOF2
[Unit]
Description=IBM Spectrum LSF Application Center
After=network.target nfs.service autofs.service gpfs.service

[Service]
Type=forking
ExecStart=/opt/ibm/lsfsuite/ext/gui/3.0/bin/ac_daemons start
ExecStop=/opt/ibm/lsfsuite/ext/gui/3.0/bin/ac_daemons stop

[Install]
WantedBy=multi-user.target
EOF2
sed -i s/"8080"/"\${PORT}"/g /opt/ibm/lsfsuite/ext/gui/conf/jvm.options
systemctl enable acd >> \${LOG} 2>&1
systemctl start acd >> \${LOG} 2>&1
echo "LSF_ROOT_USER=Y" >> \${LSF_TOP}/conf/lsf.conf
EOF1
   chmod 755 /tmp/application_center_master.sh
}

write_application_center_howto () {
   cat >> /tmp/application_center_howto.sh <<EOF1
#!/bin/sh

PORT=\$1

echo "Creating desktop icon" | tee -a \${LOG}

if test "\${USER}" = "root"
then
   HOME="/root"
else
   HOME="/home/\${USER}"
fi

DESKTOP_LINK="\${HOME}/Desktop/AC.desktop"
URL="http://\${HOSTNAME}:\${PORT}"
cat << EOF2 >> \${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox \${URL}
Name=AC
Icon=firefox
EOF2

gio set \${DESKTOP_LINK} "metadata::trusted" true
chmod 755 "\${DESKTOP_LINK}"
EOF1
   chmod 755 /tmp/application_center_howto.sh
}

############################################################
################## Application Center end ##################
############################################################

############################################################
##################### Apptainer start ######################
############################################################

write_apptainer_master () {
   cat >> /tmp/apptainer_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo "Installing Apptainer" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install apptainer >> \${LOG} 2>&1
;;
*debian*)
   add-apt-repository -y ppa:apptainer/ppa >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install apptainer >> \${LOG} 2>&1
;;
esac

if test ! -f \${SHARED}/apptainer/images/ubuntu.sif
then
   echo "Creating image ubuntu.sif" | tee -a \${LOG}
   mkdir -p \${SHARED}/apptainer/images
   apptainer build \${SHARED}/apptainer/images/ubuntu.sif docker://ubuntu >> \${LOG} 2>&1
   chmod -R 777 \${SHARED}/apptainer
fi

LSB_APPLICATIONS=\`ls \${LSF_TOP}/conf/lsbatch/*/configdir/lsb.applications\`
RET=\`egrep Apptainer \${LSB_APPLICATIONS}\`
if test "\${RET}" = ""
then
   echo "Modify LSF configuration" | tee -a \${LOG}
   cat >> \${LSB_APPLICATIONS} <<EOF2

Begin Application
NAME = apptainer
CONTAINER = apptainer[image(\${SHARED}/apptainer/images/ubuntu.sif)]
DESCRIPTION = Enable jobs running in Apptainer container
End Application
EOF2
   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd\`
      if test "\${RET}" = ""
      then
         . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
EOF1
   chmod 755 /tmp/apptainer_master.sh
}

write_apptainer_compute () {
   cat >> /tmp/apptainer_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing Apptainer" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install apptainer >> \${LOG} 2>&1
;;
*debian*)
   add-apt-repository -y ppa:apptainer/ppa >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install apptainer >> \${LOG} 2>&1
;;
esac

EOF1
   chmod 755 /tmp/apptainer_compute.sh
}

write_apptainer_howto () {
   cat >> /tmp/apptainer_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Apptainer.sh <<EOF2
#!/bin/sh

echo "Submitting apptainer job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -app apptainer -I ls -al /"
   echo
   sudo -i -u lsfadmin bsub -app apptainer -I ls -al /
;;
*)
   echo "   bsub -app apptainer -I ls -al /"
   echo
   bsub -app apptainer -I ls -al /
;;
esac
EOF2
   chmod 755 ~/HowTo_Apptainer.sh
EOF1
   chmod 755 /tmp/apptainer_howto.sh
}

############################################################
##################### Apptainer end ########################
############################################################

############################################################
####################### Aspera start #######################
############################################################

write_aspera_master () {
   cat >> /tmp/aspera_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

cd /tmp
echo "Downloading Aspera from box" | tee -a \${LOG}
echo "   Cloud-85699-AsperaEnterprise-unlim.eval.aspera-license" | tee -a \${LOG}
curl -Lo Cloud-85699-AsperaEnterprise-unlim.eval.aspera-license https://ibm.box.com/shared/static/og22fbvtvy8jlchuilpzds3ua8257oja.aspera-license >> \${LOG} 2>&1

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "   ibm-aspera-hsts-4.4.2.550-linux-64-release.rpm" | tee -a \${LOG}
   curl -Lo ibm-aspera-hsts-4.4.2.550-linux-64-release.rpm https://ibm.box.com/shared/static/zjdgxtk57k8zualghd3giz96pfv1h7p2.rpm >> \${LOG} 2>&1
   echo "Installing Aspera (~2m)" | tee -a \${LOG}
   yum -y --nogpgcheck install ibm-aspera-hsts-4.4.2.550-linux-64-release.rpm >> \${LOG} 2>&1
;;
*debian*)
   echo "   ibm-aspera-hsts-4.4.2.550-linux-64-release.deb" | tee -a \${LOG}
   curl -Lo ibm-aspera-hsts-4.4.2.550-linux-64-release.deb https://ibm.box.com/shared/static/b1f5v36sgz13n2cjq10z0pue8ykv0e2a.deb >> \${LOG} 2>&1
   echo "Installing Aspera (~2m)" | tee -a \${LOG}
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install ./ibm-aspera-hsts-4.4.2.550-linux-64-release.deb >> \${LOG} 2>&1
;;
esac
cp Cloud-85699-AsperaEnterprise-unlim.eval.aspera-license /opt/aspera/etc/aspera-license
EOF1
   chmod 755 /tmp/aspera_master.sh
}

write_aspera_howto () {
   cat >> /tmp/aspera_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

cat >> ~/HowTo_Aspera.sh <<EOF2
echo "Executing:"
echo "   ascp -A"
echo
ascp -A
EOF2
   chmod 755 ~/HowTo_Aspera.sh
EOF1
   chmod 755 /tmp/aspera_howto.sh
}

############################################################
######################## Aspera end ########################
############################################################

############################################################
######################## BLAST start #######################
############################################################

write_blast () {
   cat >> /tmp/blast.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

cd /tmp
echo "Download BLAST" | tee -a \${LOG}
curl -LO https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.15.0+-x64-linux.tar.gz >> \${LOG} 2>&1
echo "Installing BLAST" | tee -a \${LOG}
tar xvzf ncbi-blast-*-x64-linux.tar.gz >> \${LOG} 2>&1
cp ncbi-blast-*/bin/* /usr/bin
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install perl-JSON-PP perl-core >> \${LOG} 2>&1
;;
esac
EOF1
   chmod 755 /tmp/blast.sh
}

write_blast_howto () {
   cat >> /tmp/blast_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

cat >> ~/HowTo_BLAST.sh <<EOF2
#!/bin/sh

echo "Submitting BLAST job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -I blastn -version"
   echo
   sudo -i -u lsfadmin bsub -I blastn -version
;;
*)
   echo "   bsub -I blastn -version"
   echo
   bsub -I blastn -version
;;
esac
echo
echo "Further (potential) step:"
echo
echo "update_blastdb.pl --decompress nt [*]"
echo
EOF2
   chmod 755 ~/HowTo_BLAST.sh
EOF1
   chmod 755 /tmp/blast_howto.sh
}

############################################################
######################### BLAST end ########################
############################################################

############################################################
###################### Blender start #######################
############################################################

write_blender_master () {
   cat >> /tmp/blender_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

if test ! -d \${SHARED}/Blender
then
   echo "Downloading Blender" | tee -a \${LOG}
   mkdir -p \${SHARED}/Blender
   chmod -R 777 \${SHARED}/Blender
   cd /tmp
   curl -LO  https://mirrors.sahilister.in/blender/release/Blender4.0/blender-4.0.2-linux-x64.tar.xz >> \${LOG} 2>&1
   cd \${SHARED}/Blender
   tar xf /tmp/blender-4.0.2-linux-x64.tar.xz >> \${LOG} 2>&1
   echo "Downloading array3.blend from box" | tee -a \${LOG}
   cd \${SHARED}/Blender
   echo "   array3.blend" | tee -a \${LOG}
   curl -Lo array3.blend https://ibm.box.com/shared/static/q97zkdzrwhyb2fxeldrm3abu5vwi9brz.blend >> \${LOG} 2>&1
   echo "Installing ffmpeg" | tee -a \${LOG}
   case \${ID_LIKE} in
   *rhel*|*fedora*)
      yum -y --nogpgcheck install https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm >> \${LOG} 2>&1
      yum -y --nogpgcheck install https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm >> \${LOG} 2>&1
      yum -y --nogpgcheck install https://rpmfind.net/linux/centos/8-stream/PowerTools/x86_64/os/Packages/SDL2-2.0.10-2.el8.x86_64.rpm >> \${LOG} 2>&1
      yum -y --nogpgcheck install ffmpeg gstreamer1-libav >> \${LOG} 2>&1
   ;;
   *debian*)
      apt -y update >> \${LOG} 2>&1
      export DEBIAN_FRONTEND=noninteractive
      apt -y -qq install ffmpeg >> \${LOG} 2>&1
   ;;
   esac
fi

RET=\`egrep LSF_ROOT_USER \${LSF_TOP}/conf/lsf.conf\`
if test "\${RET}" = ""
then
   echo "LSF_ROOT_USER=Y" >> \${LSF_TOP}/conf/lsf.conf
   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd 2>/dev/null\`
      if test "\${RET}" = ""
      then
         . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
EOF1
   chmod 755  /tmp/blender_master.sh
}

write_blender_compute () {
   cat >> /tmp/blender_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck groupinstall "Server with GUI" >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install libxkbcommon-x11-0 libegl1 >> \${LOG} 2>&1
;;
esac
EOF1
   chmod 755  /tmp/blender_compute.sh
}

write_blender_howto () {
   cat >> /tmp/blender_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

SHARED=\$1

echo | tee -a \${LOG}
echo "Argument 1 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

cat >> ~/HowTo_Blender_local.sh  <<EOF2
#!/bin/sh
MAX=200
rm -rf \${SHARED}/Blender/img_*.png \${SHARED}/Blender/out.mpg
echo "Executing \${SHARED}/Blender/blender-4.0.2-linux-x64/blender -b \${SHARED}/Blender/array3.blend -o \${SHARED}/Blender/img_### -E BLENDER_WORKBENCH -s 1 -e \\\${MAX} -a"
echo
START=\\\`date +%s\\\`
\${SHARED}/Blender/blender-4.0.2-linux-x64/blender -b \${SHARED}/Blender/array3.blend -o \${SHARED}/Blender/img_### -E BLENDER_WORKBENCH -s 1 -e \\\${MAX} -a
END=\\\`date +%s\\\`
RUNTIME=\\\`expr \\\${END} - \\\${START}\\\`
echo
echo "Local run took \\\${RUNTIME} seconds"

echo
echo "Executing ffmpeg -i \${SHARED}/Blender/img_%3d.png \${SHARED}/Blender/out.mpg"
ffmpeg -i \${SHARED}/Blender/img_%3d.png \${SHARED}/Blender/out.mpg 1>/dev/null 2>/dev/null
echo
echo "Executing firefox file://\${SHARED}/Blender/out.mpg"
firefox file://\${SHARED}/Blender/out.mpg
EOF2
chmod 755 ~/HowTo_Blender_local.sh
cat >> ~/HowTo_Blender_LSF.sh  <<EOF2
#!/bin/sh
MAX=200
STEP=8
TOTAL_CORES=\\\`bhosts | egrep ok | awk 'BEGIN{N=0}{N=N+\\\$4}END{print N}'\\\`
echo "Total of \\\$TOTAL_CORES found"

rm -rf \${SHARED}/Blender/img_*.png \${SHARED}/Blender/out.mpg

gnome-terminal --zoom=0.6 --geometry 100x12 -- bash /tmp/watchdog.sh 1>/dev/null 2>/dev/null &

# Ask for TOTAL_CORES cores...
bsub -K -J prepare -n \\\${TOTAL_CORES} sleep 10
# Make sure all is gone
RUNPEND=1
while test \\\${RUNPEND} -gt 0
do
   RUNPEND=\\\`bjobs -rp 2>/dev/null | egrep '(RUN|PEND)' | wc -l\\\`
   sleep 1
done

START=\\\`date +%s\\\`
CNT=1
while test \\\${CNT} -le \\\${MAX}
do
   RUNPEND=\\\${TOTAL_CORES}
   while test \\\${RUNPEND} -ge \\\${STEP}
   do
      RUNPEND=\\\`bjobs -rp 2>/dev/null | egrep '(RUN|PEND)' | wc -l\\\`
      sleep 2
EOF2
chmod 755 ~/HowTo_Blender_local.sh

cat >> ~/HowTo_Blender_LSF.sh  <<EOF2
#!/bin/sh
MAX=200
STEP=8
TOTAL_CORES=\\\`bhosts | egrep ok | awk 'BEGIN{N=0}{N=N+\\\$4}END{print N}'\\\`
echo "Total of \\\$TOTAL_CORES jobslots found"
rm -rf \${SHARED}/Blender/img_*.png \${SHARED}/Blender/out.mpg

gnome-terminal --zoom=0.6 --geometry 100x12 -- bash /tmp/watchdog.sh 1>/dev/null 2>/dev/null &

# Ask for TOTAL_CORES cores...
bsub -K -J prepare -n \\\${TOTAL_CORES} sleep 10
# Make sure all is gone
RUNPEND=1
while test \\\${RUNPEND} -gt 0
do
   RUNPEND=\\\`bjobs -rp 2>/dev/null | egrep '(RUN|PEND)' | wc -l\\\`
   sleep 1
done

START=\\\`date +%s\\\`
CNT=1
while test \\\${CNT} -le \\\${MAX}
do
   RUNPEND=\\\${TOTAL_CORES}
   while test \\\${RUNPEND} -ge \\\${TOTAL_CORES}
   do
      RUNPEND=\\\`bjobs -rp 2>/dev/null | egrep '(RUN|PEND)' | wc -l\\\`
      sleep 2
   done
   N=\\\`expr \\\${CNT} + \\\${STEP} - 1\\\`
   echo bsub -J "render[\\\${CNT}-\\\${N}:\\\${STEP}]" \\\\
      \${SHARED}/Blender/blender-4.0.2-linux-x64/blender \\\\
         -b \${SHARED}/Blender/array3.blend \\\\
         -o \${SHARED}/Blender/img_### \\\\
         -E BLENDER_WORKBENCH \\\\
         -s \\\${CNT} \\\\
         -e \\\${N} \\\\
         -a

   bsub -J "render[\\\${CNT}-\\\${N}:\\\${STEP}]" \\\\
      \${SHARED}/Blender/blender-4.0.2-linux-x64/blender \\\\
         -b \${SHARED}/Blender/array3.blend \\\\
         -o \${SHARED}/Blender/img_### \\\\
         -E BLENDER_WORKBENCH \\\\
         -s \\\${CNT} \\\\
         -e \\\${N} \\\\
         -a
   CNT=\\\`expr \\\${CNT} + \\\${STEP}\\\`
done

# Make sure all is gone
RUNPEND=1
while test \\\${RUNPEND} -gt 0
do
   RUNPEND=\\\`bjobs -rp 2>/dev/null | egrep '(RUN|PEND)' | wc -l\\\`
   sleep 1
done
END=\\\`date +%s\\\`
RUNTIME=\\\`expr \\\${END} - \\\${START}\\\`
echo
echo "Run through LSF with \\\${TOTAL_CORES} took \\\${RUNTIME} seconds"

echo
echo "Executing ffmpeg -i \${SHARED}/Blender/img_%3d.png \${SHARED}/Blender/out.mpg"
ffmpeg -i \${SHARED}/Blender/img_%3d.png \${SHARED}/Blender/out.mpg 1>/dev/null 2>/dev/null
echo
echo "Executing firefox file://\${SHARED}/Blender/out.mpg"
firefox file://\${SHARED}/Blender/out.mpg
EOF2
chmod 755 ~/HowTo_Blender_LSF.sh

cat >> /tmp/watchdog.sh  <<EOF2
#!/bin/sh
echo -e "\033]11;#FFFFDD\007"
watch bjobs -w
EOF2
chmod 755 /tmp/watchdog.sh

EOF1
   chmod 755 /tmp/blender_howto.sh
}

############################################################
###################### Blender end #########################
############################################################

############################################################
################# Cloudprovider API start ##################
############################################################

write_cloudprovider_api () {
   cat >> /tmp/cloudprovider_api.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

REGION=\$1
IBMCLOUD_API_KEY=\$2

export PATH="\${PATH}:/usr/local/bin"

echo "Getting Cloudprovider API" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 REGION: \${REGION}" | tee -a \${LOG}
echo "Argument 2 IBMCLOUD_API_KEY: \${IBMCLOUD_API_KEY}" | tee -a \${LOG}
echo | tee -a \${LOG}

RET=\`which ibmcloud 2>/dev/null\`
if test "\${RET}" = ""
then
   curl -fsSL https://clis.cloud.ibm.com/install/linux | sh >> \${LOG} 2>&1
   #rm -rf /root/.bluemix
   for PLUGIN in catalogs-management schematics vpc-infrastructure secrets-manager monitoring cloud-dns-services
   do
      ibmcloud plugin install \${PLUGIN} -f >> \${LOG} 2>&1
   done
fi
echo "Logging in" | tee -a \${LOG}
ibmcloud login -r \${REGION} -q | egrep '(Account:|User:)'
ibmcloud target -g \${IBMCLOUD_RESOURCE_GROUP} 1>/dev/null 2>/dev/null
ibmcloud is target --gen 2 1>/dev/null 2>/dev/null
EOF1
   chmod 755  /tmp/cloudprovider_api.sh
}

############################################################
################## Cloudprovider API end ###################
############################################################

############################################################
#################### Common stuff start ####################
############################################################

write_common_stuff () {
   cat >> /tmp/common_stuff.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

ROOTPWD=\$1
SWAP=\$2
ID_RSA_PRIV_BASE64=\$3
ID_RSA_PUB_BASE64=\$4
ADDITIONAL_USERS=\`echo \$* | awk '{for(i=5;i<=NF;i++){printf("%s ",\$i)}}'\`

echo "Common stuff" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 ROOTPWD: \${ROOTPWD}" | tee -a \${LOG}
echo "Argument 2 SWAP: \${SWAP}" | tee -a \${LOG}
echo "Argument 3 ID_RSA_PRIV_BASE64: \${ID_RSA_PRIV_BASE64}" | tee -a \${LOG}
echo "Argument 4 ID_RSA_PUB_BASE64: \${ID_RSA_PUB_BASE64}" | tee -a \${LOG}
echo "Argument 5- ADDITIONAL_USERS: \${ADDITIONAL_USERS}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "Enable EPEL" | tee -a \${LOG}
   case \${VERSION} in
   8*) MAYOR="8" ;;
   9*) MAYOR="9" ;;
   esac
   yum -y --nogpgcheck install https://dl.fedoraproject.org/pub/epel/epel-release-latest-\${MAYOR}.noarch.rpm >> \${LOG} 2>&1
   echo "Install several packages" | tee -a \${LOG}
   yum -y --nogpgcheck install git net-tools sshpass unzip strace htop bind-utils ImageMagick bc chkconfig wget >> \${LOG} 2>&1
   case \${MAYOR} in
   8)
      yum -y --nogpgcheck install python3 >> \${LOG} 2>&1
      ln -s pip3 /usr/bin/pip >> \${LOG} 2>&1
   ;;
   9)
      yum -y --nogpgcheck install pip >> \${LOG} 2>&1
   ;;
   esac
   yum -y --nogpgcheck install environment-modules >> \${LOG} 2>&1
;;
*debian*)
   echo "Install several packages" | tee -a \${LOG}
   apt-get -yq update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install git net-tools openssh-server htop imagemagick curl default-jre python3-pip nfs-kernel-server unzip >> \${LOG} 2>&1
   # disable auto-updates
   cat >> /etc/apt/apt.conf.d/20auto-upgrades <<EOF2
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF2
   apt -y -qq install environment-modules >> \${LOG} 2>&1
   echo ". /usr/share/modules/init/bash" >> /root/.bashrc
;;
esac

MYIP_INT=\`ifconfig | fgrep "inet " | awk '{print \$2}' | head -1\`
RET=\`egrep \${HOSTNAME} /etc/hosts\`
if test "\${RET}" = ""
then
   echo "\${MYIP_INT} \${HOSTNAME}" >> /etc/hosts
fi

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "Disable firewalld" | tee -a \${LOG}
   systemctl disable firewalld >> \${LOG} 2>&1
   systemctl stop firewalld >> \${LOG} 2>&1
   echo "Enable chronyd" | tee -a \${LOG}
   systemctl enable chronyd >> \${LOG} 2>&1
   systemctl start chronyd >> \${LOG} 2>&1
   echo "Modify selinux" | tee -a \${LOG}
   sed -i s/"enforcing"/"disabled"/g /etc/selinux/config
   sed -i s/"permissive"/"disabled"/g /etc/selinux/config
   echo "Set root password" | tee -a \${LOG}
   echo "\${ROOTPWD}" | passwd --stdin root >> \${LOG} 2>&1
;;
*debian*)
   echo "Set root password" | tee -a \${LOG}
   sed -i s/"pam_pwquality.so"/"pam_pwquality.so dictcheck=0"/g /etc/pam.d/common-password
   echo "root:\${ROOTPWD}" | chpasswd >> \${LOG} 2>&1
   echo "Disable cleanup of /tmp" | tee -a \${LOG}
   cat >> /etc/tmpfiles.d/tmp.conf <<EOF2
# Clear tmp directories separately, to make them easier to override
#D /tmp 1777 root root -
#q /var/tmp 1777 root root 30d
EOF2
;;
esac
mkdir -p /root/.ssh
echo "\${ID_RSA_PRIV_BASE64}" | base64 -d > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
echo "\${ID_RSA_PUB_BASE64}" | base64 -d > /root/.ssh/id_rsa.pub
chmod 644 /root/.ssh/id_rsa.pub
cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

echo "Modify sshd" | tee -a \${LOG}
egrep -v '(PasswordAuthentication|PermitRootLogin)' /etc/ssh/sshd_config >> /etc/ssh/sshd_config_NEW
mv /etc/ssh/sshd_config_NEW /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
chmod 600 /etc/ssh/sshd_config
RET=\`egrep "StrictHostKeyChecking no" /etc/ssh/ssh_config\`
if test "\${RET}" = ""
then
   echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
fi
systemctl restart sshd 1>/dev/null 2>/dev/null
echo "Disable IPv6" | tee -a \${LOG}
cat >> /etc/sysctl.d/70-ipv6.conf <<EOF2
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF2
sysctl --load /etc/sysctl.d/70-ipv6.conf >> \${LOG} 2>&1
echo "export PATH=\"\${PATH}:/usr/local/bin\"" >> /root/.bashrc
echo "Adding user lsfadmin" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   adduser lsfadmin >> \${LOG} 2>&1
   echo "\${ROOTPWD}" | passwd --stdin lsfadmin >> \${LOG} 2>&1
;;
*debian*)
   sed -i s/"pam_pwquality.so"/"pam_pwquality.so dictcheck=0"/g /etc/pam.d/common-password
   adduser lsfadmin --gecos "lsfadmin" --disabled-password 
   echo "lsfadmin:\${ROOTPWD}" | chpasswd >> \${LOG} 2>&1
   echo ". /usr/share/modules/init/bash" >> /home/lsfadmin/.bashrc
;;
esac
echo "lsfadmin ALL=(ALL) ALL" >> /etc/sudoers
cp -r /root/.ssh /home/lsfadmin
chown -R lsfadmin:lsfadmin /home/lsfadmin/.ssh

for USER in \${ADDITIONAL_USERS}
do
   echo "Adding user \${USER}" | tee -a \${LOG}
   case \${ID_LIKE} in
   *rhel*|*fedora*)
      adduser \${USER} >> \${LOG} 2>&1
      echo "\${ROOTPWD}" | passwd --stdin \${USER} >> \${LOG} 2>&1
   ;;
   *debian*)
      sed -i s/"pam_pwquality.so"/"pam_pwquality.so dictcheck=0"/g /etc/pam.d/common-password
      adduser \${USER} --gecos "\${USER}" --disabled-password >> \${LOG} 2>&1
      echo "\${USER}:\${ROOTPWD}" | chpasswd >> \${LOG} 2>&1
   ;;
   esac
   echo "\${USER} ALL=(ALL) ALL" >> /etc/sudoers
   cp -r /root/.ssh /home/\${USER}
   chown -R \${USER}:\${USER} /home/\${USER}/.ssh
done

swapoff /swapfile >> \${LOG} 2>&1
rm -rf /swapfile
egrep -v swap /etc/fstab >> /etc/fstab.NEW
mv /etc/fstab.NEW /etc/fstab

if test "\${SWAP}" != "" -a "\${SWAP}" != "0"
then
   echo "Creating swap" | tee -a \${LOG}
   dd if=/dev/zero of=/swapfile bs=1048576 count=\${SWAP} >> \${LOG} 2>&1
   chmod 600 /swapfile
   mkswap /swapfile >> \${LOG} 2>&1
   echo "/swapfile       swap    swap    defaults        0 0" >> /etc/fstab
fi
EOF1
   chmod 755  /tmp/common_stuff.sh
}

############################################################
##################### Common stuff end #####################
############################################################

############################################################
#################### DataManager start #####################
############################################################

write_datamanager_master () {
   cat >> /tmp/datamanager_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

RET=\`egrep ^LSF_DATA_ \${LSF_TOP}/conf/lsf.conf\`
if test "\${RET}" = ""
then
   CLUSTERNAME=\`ls \${LSF_TOP}/conf/lsf.cluster.* | awk 'BEGIN{FS="."}{print \$NF}'\`
   HOSTNAME=\`hostname -s\`
   STAGING="/staging_${CLUSTERNAME}"
   echo "Downloading datamanager from box" | tee -a \${LOG}
   cd /tmp
   curl -Lo lsf10.1_data_mgr-lnx310-x64-600489.tar.Z https://ibm.box.com/shared/static/9zh1mjjjqjm80idha4j3b9fwi9330yf1.z >> \${LOG} 2>&1
   cd \${LSF_TOP}/10.1
   tar xzf /tmp/lsf10.1_data_mgr-lnx310-x64-600489.tar.Z >> \${LOG} 2>&1
   echo "Modifying LSF configuration" | tee -a \${LOG}
   echo "LSF_DATA_HOSTS=\${HOSTNAME}" >> \${LSF_TOP}/conf/lsf.conf
   echo "LSF_DATA_PORT=1729" >> \${LSF_TOP}/conf/lsf.conf
   cat >> \${LSF_TOP}/conf/lsf.datamanager.\${CLUSTERNAME} <<EOF2
Begin Parameters
ADMINS = lsfadmin
STAGING_AREA = \${STAGING}
End Parameters
EOF2
   cat >> \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.queues <<EOF2

Begin Queue
QUEUE_NAME = transfer
DATA_TRANSFER = Y
HOSTS=\${HOSTNAME}
End Queue
EOF2
   mkdir -p \${STAGING}
   chmod 777 \${STAGING}
   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd\`
      if test "\${RET}" = ""
      then
         . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
EOF1
   chmod 755 /tmp/datamanager_master.sh
}

write_datamanager_howto () {
   cat >> /tmp/datamanager_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

cat >> ~/HowTo_DataManager.sh  <<EOF2
#!/bin/sh

echo "Executing bdata showconf"
echo
bdata showconf
EOF2
chmod 755 ~/HowTo_DataManager.sh
EOF1
chmod 755 /tmp/datamanager_howto.sh
}

############################################################
##################### DataManager end ######################
############################################################

############################################################
###################### easyEDA start #######################
############################################################

write_easyeda_master () {
   cat >> /tmp/easyeda_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`

LSF_TOP=\$1

echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

RET=\`egrep ^LSB_SSH_XFORWARD_CMD \${LSF_TOP}/conf/lsf.conf\`
if test "\${RET}" = ""
then
   echo "Modify LSF configuration" | tee -a \${LOG}
   echo "LSF_ROOT_USER=Y" >> \${LSF_TOP}/conf/lsf.conf
   cat >> \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/bin/my_ssh_forward_cmd.sh <<EOF2
#!/bin/sh
ssh -X \\\$1 \\\`bjobs -o 'command' \\\$LSB_JOBID | tail -1\\\`
EOF2
   chmod 755 \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/bin/my_ssh_forward_cmd.sh
   echo "LSB_SSH_XFORWARD_CMD=my_ssh_forward_cmd.sh" >> \${LSF_TOP}/conf/lsf.conf
   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd 2>/dev/null\`
      if test "\${RET}" = ""
      then
        . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
EOF1
   chmod 755  /tmp/easyeda_master.sh
}

write_easyeda_compute () {
   cat >> /tmp/easyeda_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Downloading easyEDA" | tee -a \${LOG}
cd /tmp
curl -LO https://image.easyeda.com/files/easyeda-linux-x64-6.5.40.zip >> \${LOG} 2>&1
echo "Installing easyEDA" | tee -a \${LOG}
unzip easyeda-linux-x64-6.5.40.zip >> \${LOG} 2>&1
chmod 755 install.sh
./install.sh
case \$ID_LIKE in
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install libgtk-3-0 libgbm-dev >> \${LOG} 2>&1
;;
esac
EOF1
   chmod 755  /tmp/easyeda_compute.sh
}

write_easyeda_howto () {
   cat >> /tmp/easyeda_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

cat >> ~/HowTo_easyEDA.sh  <<EOF2
#!/bin/sh

echo "Executing:"
echo "   bsub -XF /opt/easyeda/easyeda --no-sandbox"
echo
bsub -XF /opt/easyeda/easyeda --no-sandbox
EOF2
chmod 755 ~/HowTo_easyEDA.sh
EOF1
   chmod 755 /tmp/easyeda_howto.sh
}

############################################################
####################### easyEDA end ########################
############################################################

############################################################
##################### Explorer start #######################
############################################################

write_explorer_master () {
   cat >> /tmp/explorer_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   echo "Explorer is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Install chkconfig" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install chkconfig >> \${LOG} 2>&1
;;
esac

SAVE="\${LSF_TOP}"
. \${LSF_TOP}/conf/profile.lsf
LSF_TOP="\${SAVE}"

case \${ID_LIKE} in
*debian*)
   curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic.gpg >> \${LOG} 2>&1
   echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" >> /etc/apt/sources.list.d/elastic-7.x.list
   apt update >> \${LOG} 2>&1
;;
esac

echo "Install Elasticsearch" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.2.1-x86_64.rpm >> \${LOG} 2>&1
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install elasticsearch >> \${LOG} 2>&1
;;
esac

echo "Install Logstash" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install https://artifacts.elastic.co/downloads/logstash/logstash-7.2.1.rpm >> \${LOG} 2>&1
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install logstash >> \${LOG} 2>&1
;;
esac

echo "Install Kibana" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install  https://artifacts.elastic.co/downloads/kibana/kibana-7.2.1-x86_64.rpm >> \${LOG} 2>&1
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install kibana >> \${LOG} 2>&1
;;
esac

echo "Install Elasticsearch" | tee -a \${LOG}
systemctl enable elasticsearch >> \${LOG} 2>&1
systemctl start elasticsearch >> \${LOG} 2>&1

echo "Wait for elasticsearch ready" | tee -a \${LOG}
RET=""
while test "\${RET}" = ""
do
   RET=\`curl localhost:9200 2>/dev/null\`
   echo -n "."
   sleep 1
done
echo

echo "Install Explorer Server" | tee -a \${LOG}


cd /tmp
echo "Downloading Explorer from box" | tee -a \${LOG}
echo "   explorer10.2.0.11_server_linux-x64.tar.gz" | tee -a \${LOG}
curl -Lo explorer10.2.0.11_server_linux-x64.tar.gz https://ibm.box.com/shared/static/j4hwj2bs182vloesmgxqp0ipnploi6rj.gz >> \${LOG} 2>&1
echo "   explorer10.2.0.11_node_linux-x64.tar.gz" | tee -a \${LOG}
curl -Lo explorer10.2.0.11_node_linux-x64.tar.gz https://ibm.box.com/shared/static/cj69b7is70ejcrn3ae6gwdos0dqj9gpt.gz >> \${LOG} 2>&1

echo "Installing Explorer Server" | tee -a \${LOG}
tar xzf explorer10.2.0.11_server_linux-x64.tar.gz >> \${LOG} 2>&1
cd explorer10.2.0.11_server_linux-x64
echo "ES_HOST=localhost" >> install.config
echo "1" | ./ExplorerServerInstaller.sh -f install.config >> \${LOG} 2>&1

echo "Installing Explorer Datacollector" | tee -a \${LOG}
cd /tmp
tar xzf explorer10.2.0.11_node_linux-x64.tar.gz >> \${LOG} 2>&1
cd explorer10.2.0.11_node_linux-x64
sed -i s/"rpm \\\${rpm_dbpath} -ql ibm-jre"/"echo \/opt\/ibm\/jre "/g ExplorerNodeInstaller.sh
cat >> install.config <<EOF2
EXPLORER_NODE_TOP=/opt/IBM/ExplorerNode
COLLECTED_DATA_TYPE=ALL
JDBC_CONNECTION_URL=localhost:9200
LSF_ENVDIR=\${LSF_TOP}/conf
LSF_VERSION=10
ES_HTTP_PORT=9200
EXPLORER_NODE_PORT=4046
EXPLORER_ADMIN=lsfadmin
EOF2
echo "1" | ./ExplorerNodeInstaller.sh -f install.config >> \${LOG} 2>&1

cat >> /etc/init.d/explorer <<EOF2
#!/bin/sh
# chkconfig: 2345 41 61
# The following is for the Linux insserv utility
### BEGIN INIT INFO
# Provides: explorer
# Required-Start: \\\$remote_fs
# Required-Stop: \\\$remote_fs
# Default-Start: 3 5
# Default-Stop: 0 1 2 6
# Description: Start EXPLORER daemons
### END INIT INFO

if test -f /opt/ibm/lsfsuite/ext/profile.platform
then
   . /opt/ibm/lsfsuite/ext/profile.platform
fi
if test -f /opt/IBM/ExplorerNode/lsfsuite/ext/perf/conf/profile.perf
then
   . /opt/IBM/ExplorerNode/lsfsuite/ext/perf/conf/profile.perf
fi
if test -f /opt/ibm/lsfsuite/ext/perf/conf/profile.perf
then
   . /opt/ibm/lsfsuite/ext/perf/conf/profile.perf
fi

case "\\\$1" in
'start')
   pmcadmin start
   perfadmin start all
   exit 0
;;
'stop')
   pmcadmin stop
   perfadmin stop all
   exit 0
;;
esac
EOF2
chmod 755 /etc/init.d/explorer
chkconfig --add explorer >> \${LOG} 2>&1

# Change port from 8080 to 9999
sed -i s/"8080"/"9999"/g /opt/ibm/lsfsuite/ext/gui/conf/jvm.options
service explorer start

# Too dangerous, would set JAVA_HOME ;=(
#ln -s /opt/IBM/ExplorerNode/lsfsuite/ext/perf/conf/profile.perf /etc/profile.d/profile.perf.sh
#ln -s /opt/ibm/lsfsuite/ext/profile.platform /etc/profile.d/profile.platform.sh
EOF1
   chmod 755 /tmp/explorer_master.sh
}

write_explorer_howto () {
   cat >> /tmp/explorer_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

cat >> ~/HowTo_Explorer.sh <<EOF2
#!/bin/sh

echo "Executing Explorer in browser"
echo
firefox http://localhost:9999
EOF2
chmod 755 ~/HowTo_Explorer.sh
EOF1
chmod 755 /tmp/explorer_howto.sh
}

############################################################
###################### Explorer end ########################
############################################################


############################################################
##################### Geekbench start ######################
############################################################

write_geekbench_compute () {
   cat >> /tmp/geekbench_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Downloading Geekbench" | tee -a \${LOG}
cd /tmp
curl -LO https://cdn.geekbench.com/Geekbench-6.2.2-Linux.tar.gz >> \${LOG} 2>&1
echo "Installing Geekbench" | tee -a \${LOG}
tar xzf Geekbench-*.tar.gz >> \${LOG} 2>&1
cd Geekbench-*-Linux
cp * /usr/bin
echo "
EOF1
   chmod 755 /tmp/geekbench_compute.sh
}

write_geekbench_howto () {
   cat >> /tmp/geekbench_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Geekbench.sh <<EOF2
#!/bin/sh

echo "Submitting geekbench job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -I geekbench6"
   echo
   sudo -i -u lsfadmin bsub -I geekbench6
;;
*)
   echo "   bsub -I geekbench6"
   echo
   bsub -I geekbench6
;;
esac
EOF2
   chmod 755 ~/HowTo_Geekbench.sh
EOF1
   chmod 755 /tmp/geekbench_howto.sh
}

############################################################
###################### Geekbench end #######################
############################################################

############################################################
##################### Guacamole start ######################
############################################################

write_guacamole_master () {
   cat >> /tmp/guacamole_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

ROOTPWD=\$1
PORT=\$2

echo | tee -a \${LOG}
echo "Argument 1 ROOTPWD: \${ROOTPWD}" | tee -a \${LOG}
echo "Argument 2 PORT: \${PORT}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Disable IPv6" | tee -a \${LOG}
cat >> /etc/sysctl.d/70-ipv6.conf <<EOF2
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF2
sysctl --load /etc/sysctl.d/70-ipv6.conf >> \${LOG} 2>&1
echo "Adding user guacd" | tee -a \${LOG}
useradd -M -d /var/lib/guacd/ -r -s /sbin/nologin -c "Guacd User" guacd >> \${LOG} 2>&1
mkdir -p /var/lib/guacd >> \${LOG} 2>&1
chown -R guacd: /var/lib/guacd >> \${LOG} 2>&1

echo "Getting several packages" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install make gcc libpng-devel libjpeg-devel cairo-devel libuuid-devel >> \${LOG} 2>&1
   yum -y --nogpgcheck install tomcat tomcat-admin-webapps tomcat-webapps >> \${LOG} 2>&1
   yum -y --nogpgcheck install ImageMagick >> \${LOG} 2>&1
   yum -y --nogpgcheck install zip >> \${LOG} 2>&1
   case \${VERSION} in
   8*)
      MAYOR="8"
      GUAC_VERS="1.5.5"
   ;;
   9*)
      MAYOR="9"
      GUAC_VERS="1.5.3"
   ;;
   esac
;;
*debian*)
   apt-get -yq update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install build-essential libcairo2-dev libjpeg-turbo8-dev \
      libpng-dev libtool-bin libossp-uuid-dev libvncserver-dev \
      freerdp2-dev libssh2-1-dev libtelnet-dev libwebsockets-dev \
      libpulse-dev libvorbis-dev libwebp-dev libssl-dev \
      libpango1.0-dev libswscale-dev libavcodec-dev libavutil-dev \
      libavformat-dev >> \${LOG} 2>&1
   apt -y -qq install tomcat9 tomcat9-admin tomcat9-common tomcat9-user >> \${LOG} 2>&1
   apt -y -qq install imagemagick >> \${LOG} 2>&1
   GUAC_VERS="1.5.5"
;;
esac

echo "Getting guacamole packages" | tee -a \${LOG}
cd /tmp
curl -Lo guacamole-server-\${GUAC_VERS}.tar.gz https://apache.org/dyn/closer.lua/guacamole/\${GUAC_VERS}/source/guacamole-server-\${GUAC_VERS}.tar.gz?action=download >> \${LOG} 2>&1
curl -Lo guacamole-\${GUAC_VERS}.war https://apache.org/dyn/closer.lua/guacamole/\${GUAC_VERS}/binary/guacamole-\${GUAC_VERS}.war?action=download >> \${LOG} 2>&1

case \${ID_LIKE} in
*rhel*|*fedora*)
   case \${VERSION} in
   8*)
      curl -Lo libguac-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm  https://ibm.box.com/shared/static/wqw7vm6bw3jyay0lfdsmzpdm743w4oz1.rpm >> \${LOG} 2>&1
   ;;
   9*)
      curl -Lo libguac-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm  https://ibm.box.com/shared/static/49a4215uvb7wgv83e6ks7dgvn4ehnxvw.rpm >> \${LOG} 2>&1
   ;;
   esac
   yum -y --nogpgcheck install libguac-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm >> \${LOG} 2>&1
   case \${VERSION} in
   8*)
      curl -Lo libguac-client-rdp-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm https://ibm.box.com/shared/static/uuien9qzocs9lk45or51lwrqghfkjb8w.rpm >> \${LOG} 2>&1
   ;;
   9*)
      curl -Lo libguac-client-rdp-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm https://ibm.box.com/shared/static/hi3s0eq2zrimc7ag2dt1e86ctpl1lqpo.rpm >> \${LOG} 2>&1
   ;;
   esac
   yum -y --nogpgcheck install libguac-client-rdp-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm >> \${LOG} 2>&1
   case \${VERSION} in
   8*)
      curl -Lo libguac-client-ssh-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm https://ibm.box.com/shared/static/7hvyeojepwufeg7iw5jgoulhmynqek2p.rpm >> \${LOG} 2>&1
   ;;
   9*)
      curl -Lo libguac-client-ssh-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm https://ibm.box.com/shared/static/ae2kmlgfzc4fcq6qw51efuu717lc4dy8.rpm >> \${LOG} 2>&1
   ;;
   esac
   yum -y --nogpgcheck install libguac-client-ssh-\${GUAC_VERS}-1.el\${MAYOR}.x86_64.rpm >> \${LOG} 2>&1
;;
esac

echo "Compiling guacamole server" | tee -a \${LOG}
rm -rf /tmp/guacamole
mkdir -p /tmp/guacamole
cd /tmp/guacamole
tar xzf /tmp/guacamole-server-\${GUAC_VERS}.tar.gz
cd /tmp/guacamole/guacamole-server-\${GUAC_VERS}
./configure --with-systemd-dir=/etc/systemd/system >> \${LOG} 2>&1
make >> \${LOG} 2>&1
make install >> \${LOG} 2>&1
ldconfig >> \${LOG} 2>&1
sed -i 's/daemon/guacd/' /etc/systemd/system/guacd.service

echo "Customizing guacamole" | tee -a \${LOG}
# https://docs.cloudron.io/apps/guacamole/
mkdir -p /etc/guacamole/extensions
rm -rf /tmp/guacamole_branding
mkdir -p /tmp/guacamole_branding
cd /tmp/guacamole_branding
curl -LO https://github.com/Zer0CoolX/guacamole-customize-loginscreen-extension/raw/master/branding.jar >> \${LOG} 2>&1
unzip branding.jar >> \${LOG} 2>&1
sed -i s/"Title Here"/"HybridCloud RDP"/g translations/en.json
rm -rf branding.jar
rm -rf images/logo-placeholder.png
zip -r /etc/guacamole/extensions/branding.jar * >> \${LOG} 2>&1

echo "Starting guacd" | tee -a \${LOG}
systemctl daemon-reload >> \${LOG} 2>&1
systemctl enable guacd >> \${LOG} 2>&1
systemctl start guacd >> \${LOG} 2>&1

echo "Copying guacamole.war" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   rm -rf /var/lib/tomcat/webapps/ROOT
   cp /tmp/guacamole-\${GUAC_VERS}.war /var/lib/tomcat/webapps/ROOT.war
   mkdir -p /etc/guacamole /usr/share/tomcat/.guacamole
;;
*debian*)
   rm -rf /var/lib/tomcat9/webapps/ROOT
   cp /tmp/guacamole-\${GUAC_VERS}.war /var/lib/tomcat9/webapps/ROOT.war
   mkdir -p /etc/guacamole /usr/share/tomcat9/.guacamole
;;
esac

echo "Configuring guacamole and tomcat" | tee -a \${LOG}
cat >> /etc/guacamole/guacd.conf <<EOF2
[server]
bind_host = 127.0.0.1
bind_port = 4822
EOF2
cat >> /etc/guacamole/guacamole.properties <<EOF2
guacd-hostname: 127.0.0.1
guacd-port:         4822
user-mapping:       /etc/guacamole/user-mapping.xml
auth-provider:      net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
basic-user-mapping: /etc/guacamole/user-mapping.xml
EOF2
case \${ID_LIKE} in
*rhel*|*fedora*)
   ln -s /etc/guacamole/guacamole.properties /usr/share/tomcat/.guacamole/ >> \${LOG} 2>&1
;;
*debian*)
   ln -s /etc/guacamole/guacamole.properties /usr/share/tomcat9/.guacamole/ >> \${LOG} 2>&1
;;
esac

cat >> /etc/guacamole/user-mapping.xml <<EOF2
<user-mapping>
EOF2

ALL_USERS="root lsfadmin"
for USER in \${ALL_USERS} \${ADDITIONAL_USERS}
do
   echo "Adding user \${USER} and changing password" | tee -a \${LOG}
   cat >> /etc/guacamole/user-mapping.xml <<EOF2
        <authorize username="\${USER}" password="\${ROOTPWD}" >
                <connection name="\${HOSTNAME} RDP">
                        <protocol>rdp</protocol>
                        <param name="hostname">\${HOSTNAME}</param>
                        <param name="username">\${USER}</param>
                        <param name="port">3389</param>
                        <param name="ignore-cert">true</param>
                        <param name="server-layout">de-de-qwertz</param>
                </connection>
                <connection name="\${HOSTNAME} SSH">
                        <protocol>ssh</protocol>
                        <param name="hostname">\${HOSTNAME}</param>
                        <param name="username">root</param>
                        <param name="port">22</param>
                        <param name="color-scheme">black-white</param>
                </connection>
        </authorize>
EOF2
   case \${ID_LIKE} in
   *rhel*|*fedora*)
   echo "\${ROOTPWD}" | passwd --stdin \${USER} >> \${LOG} 2>&1
   ;;
   *debian*)
      sed -i s/"pam_pwquality.so"/"pam_pwquality.so dictcheck=0"/g /etc/pam.d/common-password
      echo "\${USER}:\${ROOTPWD}" | chpasswd >> \${LOG} 2>&1
   ;;
   esac
done

cat >> /etc/guacamole/user-mapping.xml <<EOF2
</user-mapping>
EOF2
chmod 600 /etc/guacamole/user-mapping.xml
chown tomcat:tomcat /etc/guacamole/user-mapping.xml
case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "guacamole.home=/etc/guacamole" >> /etc/tomcat/catalina.properties
;;
*debian*)
   echo "guacamole.home=/etc/guacamole" >> /etc/tomcat9/catalina.properties
;;
esac

echo "Starting tomcat" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   systemctl enable tomcat >> \${LOG} 2>&1
   systemctl start tomcat >> \${LOG} 2>&1
;;
*debian*)
   systemctl enable tomcat9 >> \${LOG} 2>&1
   systemctl start tomcat9 >> \${LOG} 2>&1
;;
esac

echo "Creating setup_user_desktop" | tee -a \${LOG}
cat >> /usr/bin/setup_user_desktop.sh <<EOF2
#!/bin/sh

. /etc/os-release
. /var/environment.sh

########################################
echo "yes" >> ~/.config/gnome-initial-setup-done
########################################
echo "User 01 - Modify gnome-shell-extension-desktop-icons"
gsettings set org.gnome.shell enabled-extensions "['apps-menu@gnome-shell-extensions.gcampax.github.com', 'desktop-icons@gnome-shell-extensions.gcampax.github.com', 'horizontal-workspaces@gnome-shell-extensions.gcampax.github.com', 'launch-new-instance@gnome-shell-extensions.gcampax.github.com', 'places-menu@gnome-shell-extensions.gcampax.github.com', 'top-icons@gnome-shell-extensions.gcampax.github.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'window-list@gnome-shell-extensions.gcampax.github.com']"
########################################
echo "User 02 - Modify terminal colors"
ID=\\\`gsettings list-recursively | fgrep "org.gnome.Terminal.ProfilesList default" | awk '{print \\\$3}' | sed s/"'"//g\\\`
dconf write /org/gnome/terminal/legacy/profiles:/:\\\${ID}/use-theme-colors "false"
dconf write /org/gnome/terminal/legacy/profiles:/:\\\${ID}/background-color "'rgb(255,255,255)'"
dconf write /org/gnome/terminal/legacy/profiles:/:\\\${ID}/foreground-color "'rgb(0,0,0)'"
########################################
echo "User 03 - Set blankscreen timeout"
gsettings set org.gnome.desktop.session idle-delay 0
########################################
echo "User 04 - Extend languages/kbd"
dconf write /org/gnome/desktop/input-sources/sources "[('xkb', 'de'), ('xkb', 'fr'), ('xkb', 'gb')]"
########################################
echo "User 08 - Modifying ~/.bashrc"
echo "Modifying \${HOME}/.bashrc"
cat >> ~/.bashrc <<EOF3
cd
EOF3
########################################
echo "User 09 - Create desktop links"

ICON_TERMINAL="utilities-terminal"
if test -f /usr/share/icons/Yaru/48x48/apps/gnome-terminal.png
then
   ICON_TERMINAL="/usr/share/icons/Yaru/48x48/apps/gnome-terminal.png"
fi
if test -f /usr/share/icons/Yaru/48x48@2x/apps/terminal-app.png
then
   ICON_TERMINAL="/usr/share/icons/Yaru/48x48@2x/apps/terminal-app.png"
fi
ICON_MONITOR="/usr/share/icons/HighContrast/scalable/apps/utilities-system-monitor.svg"
if test -f /usr/share/icons/Yaru/48x48/apps/gnome-system-monitor.png
then
   ICON_MONITOR="/usr/share/icons/Yaru/48x48/apps/gnome-system-monitor.png"
fi
if test -f /usr/share/icons/HighContrast/scalable/apps/utilities-system-monitor.svg
then
   ICON_MONITOR="/usr/share/icons/HighContrast/scalable/apps/utilities-system-monitor.svg"
fi

DESKTOP_LINK="\\\${HOME}/Desktop/Monitor.desktop"
cat << EOF3 >> \\\${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=gnome-system-monitor -r
Name=Monitor
Icon=\\\${ICON_MONITOR}
EOF3
gio set \\\${DESKTOP_LINK} "metadata::trusted" true
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
chmod 755 "\\\${DESKTOP_LINK}"
DESKTOP_LINK="\\\${HOME}/Desktop/Terminal.desktop"
cat << EOF3 >> \\\${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=gnome-terminal
Name=Terminal
Icon=\\\${ICON_TERMINAL}
EOF3
gio set \\\${DESKTOP_LINK} "metadata::trusted" true
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
chmod 755 "\\\${DESKTOP_LINK}"

#rm -rf ~/.config/autostart/start_node.desktop 1>/dev/null 2>/dev/null
EOF2
chmod 755  /usr/bin/setup_user_desktop.sh

echo "Handling xrdp" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install tigervnc-server xrdp >> \${LOG} 2>&1
   yum -y --nogpgcheck groupinstall "Server with GUI" >> \${LOG} 2>&1
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install ubuntu-desktop desktopfolder >> \${LOG} 2>&1
   apt -y -qq install tigervnc-standalone-server tigervnc-xorg-extension tigervnc-viewer xrdp >> \${LOG} 2>&1
;;
esac

ALL_USERS="root lsfadmin"
for USER in \${ALL_USERS} \${ADDITIONAL_USERS}
do
   if test "\${USER}" = "root"
   then
      HOME="/root"
   else
      HOME="/home/\${USER}"
   fi

   mkdir -p \${HOME}/.config/autostart
   cat >> \${HOME}/.config/autostart/start_node.desktop <<EOF2
[Desktop Entry]
Exec=gnome-terminal -e "bash -c \\\"setup_user_desktop.sh\\\""
Type=Application
EOF2
   echo "yes" >> \${HOME}/.config/gnome-initial-setup-done
   chown -R \${USER}:\${USER} \${HOME}/.config
done

case \${ID_LIKE} in
*rhel*|*fedora*)
   sed -i s/"AutomaticLogin"/"#AutomaticLogin"/g /etc/gdm/custom.conf
;;
*debian*)
   sed -i s/"AutomaticLogin"/"#AutomaticLogin"/g /etc/gdm3/custom.conf
;;
esac

systemctl enable xrdp >> \${LOG} 2>&1
systemctl start xrdp >> \${LOG} 2>&1

yum -y install mesa-libEGL-23.3.3 mesa-libGL-23.3.3 >> \${LOG} 2>&1

if test "\${PORT}" != "8080"
then
   echo "Redirecting \${PORT} -> 8080" | tee -a \${LOG}
   case \${ID_LIKE} in
   *rhel*|*fedora*)
      systemctl stop firewalld >> \${LOG} 2>&1
      systemctl disable firewalld >> \${LOG} 2>&1
      systemctl mask firewalld >> \${LOG} 2>&1
      yum -y --nogpgcheck install iptables-services >> \${LOG} 2>&1
      systemctl enable iptables >> \${LOG} 2>&1
      systemctl start iptables >> \${LOG} 2>&1
      /sbin/iptables -t nat -I PREROUTING -p tcp --dport \${PORT} -j REDIRECT --to-port 8080 >> \${LOG} 2>&1
      cat >> /etc/sysconfig/iptables <<EOF2
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [14:978]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m tcp --dport 1:65535
-A INPUT -p udp -m udp --dport 1:65535
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport \${PORT} -j REDIRECT --to-ports 8080
COMMIT
EOF2
      systemctl restart iptables >> \${LOG} 2>&1
   ;;
   *debian*)
      systemctl enable ufw >> \${LOG} 2>&1
      systemctl stop ufw
      systemctl start ufw
      ufw enable >> \${LOG} 2>&1

      echo "net/ipv4/ip_forward=1" >> /etc/ufw/sysctl.conf
      cat >> /etc/ufw/user.rules <<EOF2
*filter
-A ufw-user-input -p tcp --dport 1:65535 -j ACCEPT
-A ufw-user-input -p tcp --dport 1:65535 -j ACCEPT
COMMIT
EOF2
      cat >> /etc/ufw/before.rules <<EOF2
*nat
-A PREROUTING -p tcp --dport \${PORT} -j REDIRECT --to-port 8080
COMMIT
EOF2
      systemctl stop ufw
      systemctl start ufw

      cat >> /usr/bin/ufw_watchdog.sh <<EOF2
#!/bin/sh

ufw enable
systemctl stop ufw
systemctl disable ufw
systemctl enable ufw
systemctl restart ufw
ufw disable
EOF2
      chmod 755 /usr/bin/ufw_watchdog.sh

      cat >> /etc/systemd/system/ufw_watchdog.service <<EOF2
[Unit]
Description=UFW watchdog

[Service]
Type=simple
ExecStart=/usr/bin/ufw_watchdog.sh
StandardOutput=syslog
#StandardError=syslog
SyslogIdentifier=ufw_watchdog

[Install]
WantedBy=multi-user.target
EOF2
      systemctl enable ufw_watchdog
      systemctl start ufw_watchdog
   ;;
   esac
fi

echo "Creating new backgrounds" | tee -a \${LOG}
if test -d /usr/share/backgrounds
then
   cd /usr/share/backgrounds
   rm -rf *ORIG
   for IMG in \`ls *.jpg *.png 2>/dev/null\`
   do
      SIZE=\`identify \$IMG | awk '{print \$3}'\`
      WIDTH=\`echo \${SIZE} | awk 'BEGIN{FS="x"}{print \$1}'\`
      POINTSIZE=\`expr \${WIDTH} / 20\`
      SHORT=\`echo \${IMG} | sed -e s/".jpg"//g -e s/".png"//g\`
      SUFFIX=\`echo \${IMG} | awk 'BEGIN{FS="."}{print \$NF}'\`
      rm -rf \${IMG}
      if test -f /var/custom_image.jpg
      then
         convert /var/custom_image.jpg -size \${SIZE} -pointsize \${POINTSIZE} -gravity center -annotate 0 "\${HOSTNAME}" \$IMG >> \${LOG} 2>&1
      else
         convert -size \${SIZE} xc:white -pointsize \${POINTSIZE} -gravity center label:"\${HOSTNAME}" \$IMG >> \${LOG} 2>&1
         rm -rf \${SHORT}-0.\${SUFFIX}
         mv \${SHORT}-1.\${SUFFIX} \${SHORT}.\${SUFFIX} >> \${LOG} 2>&1
      fi
   done
fi

echo "Annotating" | tee -a \${LOG}
cat >> /usr/bin/annotate.sh <<EOF2
#!/bin/sh

sleep 2

. /etc/os-release
. /var/environment.sh

HOSTNAME=\\\`hostname -s\\\`
ADD_HN="\\\${HOSTNAME}     \n"
FQDN=\\\`hostname -f\\\`
if test "\\\${HOSTNAME}" != "\\\${FQDN}"
then
   ADD_FQDN="FQDN: \\\${FQDN}     \n"
fi

REL=\\\`echo \\\${NAME} \\\${VERSION_ID} | awk '{printf("OS: %s\n",\\\$0)}'\\\`
ADD_REL="\\\${REL}     \n"

FIRST_IF=\\\`ifconfig 2>/dev/null | egrep '(ens|enp|eth)' | egrep -v ether | awk 'BEGIN{FS=":"}{print \\\$1}' | head -1\\\`
FIRST_IP=\\\`ifconfig \\\${FIRST_IF} 2>/dev/null | fgrep "inet " | awk '{print \\\$2}'\\\`
if test "\\\${FIRST_IP}" = ""
then
   FIRST_IP=\\\`ifconfig br-ex 2>/dev/null | fgrep "inet " | awk '{print \\\$2}'\\\`
fi
SECOND_IF=\\\`ifconfig 2>/dev/null | egrep '(ens|enp|eth)' | egrep -v ether | awk 'BEGIN{FS=":"}{print \\\$1}' | tail -1\\\`
SECOND_IP=\\\`ifconfig \\\${SECOND_IF} 2>/dev/null | fgrep "inet " | awk '{print \\\$2}'\\\`

if test "\\\${SECOND_IP}" = "" -o "\\\${SECOND_IP}" = "\\\${FIRST_IP}"
then
   ADD_IP="IP \\\${FIRST_IF}: \\\${FIRST_IP}     \n"
else
   ADD_IP="IP \\\${FIRST_IF}: \\\${FIRST_IP}     \nIP \\\${SECOND_IF}: \\\${SECOND_IP}     \n"
fi

ADD_SF=""
for CAND in /mnt/hgfs /media
do
   RES=\\\`ls \\\${CAND} 2>/dev/null\\\`
   for SUB in \\\${RES}
   do
      CONT=\\\`ls \\\${CAND}/\\\${SUB}/* 2>/dev/null\\\`
      if test "\\\${CONT}" != ""
      then
         ADD_SF="\\\${ADD_SF}Shared Folder: \\\${CAND}/\\\${SUB}     \n"
      fi
   done
done

ADD_CORES=\\\`lscpu | egrep "^CPU\(s\):" | awk '{printf("Cores: %s     \\\\\\\\\n",\\\$2)}'\\\`
ADD_MEM=\\\`cat /proc/meminfo | egrep "MemTotal:" | awk '{printf("Mem: %.1f GiB     \\\\\\\\\n",\\\$2/1048576)}'\\\`
ADD_SWAP=\\\`cat /proc/meminfo | egrep "SwapTotal:" | awk '{printf("Swap: %.1f GiB     \\\\\\\\\n",\\\$2/1048576)}'\\\`

case \\\$ID_LIKE in
*rhel*|*fedora*)
   PS=30
   XOFFSET=0
;;
*debian*)
   PS=30
   XOFFSET=100
;;
esac
for BACKGROUND in \\\`ls /usr/share/backgrounds/*.jpg /usr/share/backgrounds/*.png 2>/dev/null | egrep -v _ORIG\\\`
do
   if test ! -f \\\${BACKGROUND}_ORIG
   then
      cp \\\${BACKGROUND} \\\${BACKGROUND}_ORIG
   fi
   convert -pointsize \\\${PS} -annotate +\\\${XOFFSET}+0 "\n\n\n\n\n\n\n\nHostname: \\\${ADD_HN}\\\${ADD_FQDN}\\\${ADD_REL}\\\${ADD_CORES}\\\${ADD_MEM}\\\${ADD_SWAP}\\\${ADD_IP}\\\${ADD_SF}" -gravity northeast \\\${BACKGROUND}_ORIG \\\${BACKGROUND}
done
EOF2
chmod 755 /usr/bin/annotate.sh
/usr/bin/annotate.sh
EOF1
   chmod 755 /tmp/guacamole_master.sh
}

############################################################
###################### Guacamole end #######################
############################################################

############################################################
#################### Hostfactory start #####################
############################################################

write_hostfactory_master () {
   cat >> /tmp/hostfactory_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

SYM_TOP=\$1
APIKEY=\$2

echo | tee -a \${LOG}
echo "Argument 1 SYM_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 APIKEY: \${APIKEY}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Creating Hostfactory files" | tee -a \${LOG}
cat >> \${SYM_TOP}/hostfactory/conf/providers/hostProviders.json <<EOF2
{
    "version": 2,
    "providers":[
        {
            "name": "ibmcloudgen2inst",
            "enabled": 1,
            "plugin": "ibmcloudgen2",
            "confPath": "\\\${HF_CONFDIR}/providers/ibmcloudgen2inst/",
            "workPath": "\\\${HF_WORKDIR}/providers/ibmcloudgen2inst/",
            "logPath": "\\\${HF_LOGDIR}/"
        }
    ]
}
EOF2

cat >> \${SYM_TOP}/hostfactory/conf/providerplugins/hostProviderPlugins.json <<EOF2
{
    "version": 2,
    "providerplugins":[
        {
            "name": "ibmcloudgen2",
            "enabled": 1,
            "scriptPath": "\\\${HF_TOP}/\${HF_VERSION}/providerplugins/ibmcloudgen2/scripts/"
        }
    ]
}
EOF2

cat >> \${SYM_TOP}/hostfactory/conf/providers/ibmcloudgen2inst/ibmcloudgen2instprov_config.json <<EOF2
{
  "IBMCLOUDGEN2_CREDENTIAL_FILE": "\${SYM_TOP}/hostfactory/conf/providers/ibmcloudgen2inst/credentials",
  "LOG_LEVEL":"LOG_INFO",
  "LOG_MAX_FILE_SIZE": 10,
  "LOG_MAX_ROTATE": 5,
  "ACCEPT_PROPAGATED_LOG_SETTING": true
}
EOF2

cat >> \${SYM_TOP}/hostfactory/conf/providers/ibmcloudgen2inst/credentials <<EOF2
# BEGIN ANSIBLE MANAGED BLOCK
VPC_URL=http://vpc.cloud.ibm.com/v1
VPC_AUTH_TYPE=iam
VPC_APIKEY=\${IBMCLOUD_API_KEY}
RESOURCE_RECORDS_URL=https://api.dns-svcs.cloud.ibm.com/v1
RESOURCE_RECORDS_AUTH_TYPE=iam
RESOURCE_RECORDS_APIKEY=\${IBMCLOUD_API_KEY}
# END ANSIBLE MANAGED BLOCK
EOF2

cat >> \${SYM_TOP}/hostfactory/conf/requestors/hostRequestors.json <<EOF2
{
    "version": 2,
    "requestors":[
        {
            "name": "symAinst",
            "enabled": 1,
            "plugin": "symA",
            "confPath": "\\\${HF_CONFDIR}/requestors/symAinst/",
            "workPath": "\\\${HF_WORKDIR}/requestors/symAinst/",
            "logPath": "\\\${HF_LOGDIR}/",
            "providers": ["ibmcloudgen2inst"],
            "requestMode": "POLL"
        },
        {
            "name": "admin",
            "enabled": 1,
            "providers": ["ibmcloudgen2inst"],
            "requestMode": "REST_MANUAL"
        },
        {
            "name": "cwsinst",
            "enabled": 1,
            "plugin": "cws",
            "confPath": "\\\${HF_CONFDIR}/requestors/cwsinst/",
            "workPath": "\\\${HF_WORKDIR}/requestors/cwsinst/",
            "logPath": "\\\${HF_LOGDIR}/",
            "providers": ["ibmcloudgen2inst"],
            "requestMode": "POLL"
        }
    ]
}
EOF2

cat >> \${SYM_TOP}/hostfactory/conf/requestors/symAinst/symAinstreq_config.json <<EOF2
{
    "scaling_policy": "throughput",
    "slot_mapping":
        {
            "ncores": 1,
            "nram": 256
        },
    "cloud_apps":[
        {
            "name": "symping7.3.2"
        }
    ],
    "log_parameters":
    {
       "level": "LOG_INFO",
       "max_file_size": 10,
       "max_rotate": 5
    },
    "resource_groups":["ComputeHosts"],
    "resource_plans":["ComputeHosts"],
    "host_return_policy": "lazy",
    "unavailable_host_timeout":30
}
EOF2

cat >> \${SYM_TOP}/hostfactory/conf/requestors/symAinst/symAinstreq_policy_config.json <<EOF2
{
    "scaling_policy":[
        {
            "name": "throughput",
            "description": "Throughput is the number of tasks executed per minutes per slot",
            "initial_task_duration_seconds": 1,
            "history_expiry_time": 60,
            "active_task_moving_avg": 5,
            "desired_task_complete_duration": 10,
            "max_cores_per_hour": 0,
            "ego_host_startup_time": 5,
            "ego_failover_timeout": 10,
            "startup_cores_if_no_history": 0
        }
    ],
    "host_return_policy":[
        {
            "name": "lazy",
            "description": "Return cloud hosts closer to the end of billing interval",
            "billing_interval": 60,
            "return_interval": 10,
            "return_blocked_hosts": true,
            "force_return_interval": 3,
            "return_idle_only": false,
            "allow_idle_duration_seconds": 0
        },
        {
            "name": "immediate",
            "description": "Return cloud hosts immediately",
            "return_blocked_hosts": true,
            "force_return_interval": 1,
            "return_idle_only": true,
            "allow_idle_duration_seconds": 0
        }
    ]
}
EOF2

echo "Restarting ego" | tee -a \${LOG}
systemctl restart ego
EOF1
   chmod 755 /tmp/hostfactory_master.sh
}

############################################################
##################### Hostfactory end ######################
############################################################

############################################################
################# Hostname & DynDNS start ##################
############################################################

write_hostname_dyndns () {
   cat >> /tmp/hostname_dyndns.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

MYHOSTNAME=\$1

echo "Setting hostname" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 MYHOSTNAME: \${MYHOSTNAME}" | tee -a \${LOG}
echo | tee -a \${LOG}

hostnamectl set-hostname \${MYHOSTNAME}
EOF1
   chmod 755 /tmp/hostname_dyndns.sh
}

############################################################
################## Hostname & DynDNS end ###################
############################################################

############################################################
#################### Intel-HPCKit start ####################
############################################################

write_intelhpckit () {
   cat >> /tmp/intelhpckit.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing Intel-HPCKit" | tee -a \${LOG}

case \${ID_LIKE} in 
*rhel*|*fedora*)
   yum -y --nogpgcheck install gcc-c++ >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install g++ >> \${LOG} 2>&1
;;
esac

cd /tmp
curl -LO https://registrationcenter-download.intel.com/akdlm/IRC_NAS/7f096850-dc7b-4c35-90b5-36c12abd9eaa/l_HPCKit_p_2024.1.0.560_offline.sh >> \${LOG} 2>&1
sh ./l_HPCKit_p_2024.1.0.560_offline.sh -a --silent --eula=accept >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/intelhpckit.sh
}

write_intelhpckit_howto () {
   cat >> /tmp/intelhpckit_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Intel-HPCKit.sh <<EOF2
#!/bin/sh

echo "Executing ls -al /opt/intel/oneapi:"
ls -al /opt/intel/oneapi
EOF2
chmod 755 ~/HowTo_Intel-HPCKit.sh
EOF1
   chmod 755 /tmp/intelhpckit_howto.sh
}

############################################################
##################### Intel-HPCKit end #####################
############################################################

############################################################
#################### iRODS shell start #####################
############################################################

write_irods () {
   cat >> /tmp/irods.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing iRODS shell" | tee -a \${LOG}

case \${ID_LIKE} in 
*rhel*|*fedora*)
   yum -y --nogpgcheck install pip python-devel >> \${LOG} 2>&1
   pip install python-irodsclient >> \${LOG} 2>&1
   pip install irods-shell >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install python3-pip >> \${LOG} 2>&1
   pip3 install python-irodsclient >> \${LOG} 2>&1
   pip3 install irods-shell >> \${LOG} 2>&1
;;
esac

EOF1
   chmod 755 /tmp/irods.sh
}

write_irods_howto () {
   cat >> /tmp/irods_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_iRODS_shell.sh <<EOF2
#!/bin/sh

echo "Executing /usr/local/bin/iinit:"
/usr/local/bin/iinit
EOF2
chmod 755 ~/HowTo_iRODS_shell.sh
EOF1
   chmod 755 /tmp/irods_howto.sh
}

############################################################
##################### iRODS shell end ######################
############################################################

############################################################
################## Jupyter notebook start ##################
############################################################

write_jupyter_howto () {
   cat >> /tmp/jupyter_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

cat >> ~/HowTo_Jupyter.sh <<EOF2
#!/bin/sh

USER=\\\`whoami\\\`
case \\\${USER} in
root)
   cat <<EOF3
Start a jupyter server job:
   sudo -i -u lsfadmin bsub -I hpa-jupyter-notebook.sh -s
Check status:
   sudo -i -u lsfadmin bsub -m [SERVER_HOST] -I hpa-jupyter-notebook.sh -c
Shutdown jupyter server:
   sudo -i -u lsfadmin bsub -m [SERVER_HOST] -I hpa-jupyter-notebook.sh -q
EOF3
;;
*)
   cat <<EOF3
Start a jupyter server job:
   bsub -I hpa-jupyter-notebook.sh -s
Check status:
   bsub -m [SERVER_HOST] -I hpa-jupyter-notebook.sh -c
Shutdown jupyter server:
   bsub -m [SERVER_HOST] -I hpa-jupyter-notebook.sh -q
EOF3
;;
esac
EOF2
   chmod 755 ~/HowTo_Jupyter.sh
EOF1
   chmod 755 /tmp/jupyter_howto.sh
}

write_jupyter_compute () {
   cat >> /tmp/jupyter_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

case \$ID_LIKE in
*rhel*|*fedora*)
   yum -y --nogpgcheck install pip >> \${LOG} 2>&1
   pip install --upgrade pip >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install pip >> \${LOG} 2>&1
   pip install --upgrade pip >> \${LOG} 2>&1
;;
esac
pip install notebook >> \${LOG} 2>&1

cat >> /usr/bin/hpa-jupyter-notebook.sh <<EOF2
#!/bin/bash
#
#***********************************************************#
#                                                           #
# Name: hpa-jupyter-notebook.sh                             #
#                                                           #
# (c) Copyright International Business Machines Corp 2019.  #
# US Government Users Restricted Rights -                   #
# Use, duplication or disclosure                            #
# restricted by GSA ADP Schedule Contract with IBM Corp.    #
#                                                           #
#***********************************************************#
#
# This script will run jupyter-notebook
#
#***********************************************************#
#                JUPYTER NOTEBOOK VARIABLES                 #
#***********************************************************#

JUPYTER_OK=0
JUPYTER_ERR=1
# Change the directory to yours. E.g.: JUPYTER_HOME=/opt/anaconda2
JUPYTER_HOME=/usr/local
JUPYTER_BIN_DIR=\\\$JUPYTER_HOME/bin
JUPYTER_HOST=\\\`hostname\\\`

NOTEBOOK_PARAM=
NOTEBOOK_CLI=\\\$JUPYTER_BIN_DIR/jupyter-notebook

export XDG_RUNTIME_DIR=\\\$HOME/

#***********************************************************#
# Name                 : notebook_usage
# Environment Variables: None
# Description          : Print notebook usage
# Parameters           : None
# Return Value         : None
#***********************************************************#
function notebook_usage()
{
    cat << NOTEBOOK_HELP

-------------------------------------------------------------

Usage:  hpa-jupyter-notebook.sh -s [OPTIONS]
        hpa-jupyter-notebook.sh -q [OPTIONS]
        hpa-jupyter-notebook.sh -c
        hpa-jupyter-notebook.sh -h

        -s  Start Jupyter Notebook

        -q  Stop Jupyter Notebook

        -c  Check status of Jupyter Notebook

        -h  Show this message

-------------------------------------------------------------

Options:
\\\`\\\$NOTEBOOK_CLI --help\\\`

-------------------------------------------------------------

NOTEBOOK_HELP

}

#***********************************************************#
# Name                 : notebook_status
# Environment Variables: None
# Description          : Check notebook status
# Parameters           : None
# Return Value         : None
#***********************************************************#
function notebook_status()
{
    \\\$NOTEBOOK_CLI list
}

#***********************************************************#
# Name                 : notebook_start
# Environment Variables: None
# Description          : Start jupyter-notebook
# Parameters           : CLI jupyter-notebook parameters
# Return Value         : None
#***********************************************************#
function notebook_start()
{
    echo "INFO - Starting Jupyter Notebook ..."
    if [ ! -f "\\\$NOTEBOOK_CLI" ]; then
        echo "ERROR - Cannot execute the program '\\\$NOTEBOOK_CLI'. Ensure 'JUPYTER_HOME' is set and the program is executable."
        exit \\\$JUPYTER_ERR
    fi
    blaunch -no-wait -z \\\$JUPYTER_HOST \\\$NOTEBOOK_CLI -y --ip \\\$JUPYTER_HOST --allow-root \\\$NOTEBOOK_PARAM &
    sleep 2
    notebook_status
}

#***********************************************************#
# Name                 : notebook_quit
# Environment Variables: None
# Description          : Stop jupyter-notebook
# Parameters           : CLI jupyter-notebook parameters
# Return Value         : None
#***********************************************************#
function notebook_quit()
{
    notebook_status
    \\\$NOTEBOOK_CLI stop -y \\\$NOTEBOOK_PARAM
    sleep 2
    notebook_status
}

#***********************************************************#
# Name                 : notebook_validation
# Environment Variables: JUPYTER_HOME
# Description          : Validation for jupyter-notebook
# Parameters           : None
# Return Value         : None
#***********************************************************#
function notebook_validation()
{
    if [ "\\\$JUPYTER_HOME" == "" ]; then
        echo "ERROR - Environment variable 'JUPYTER_HOME'  is not specified. Ensure 'JUPYTER_HOME' is set."
        exit \\\$JUPYTER_ERR
    fi

    if [ ! -f "\\\$NOTEBOOK_CLI" ]; then
        echo "ERROR - Cannot execute the program '\\\$NOTEBOOK_CLI'. Ensure 'JUPYTER_HOME' is set and the program is executable."
        exit \\\$JUPYTER_ERR
    fi
}

#***********************************************************#
# Name                 : jupyter_notebook
# Environment Variables: None
# Description          : Main process for jupyter-notebook
# Parameters           : CLI jupyter-notebook parameters
# Return Value         : None
#***********************************************************#
function jupyter_notebook()
{
    NOTEBOOK_PARAM=\\\${@:2}
    notebook_validation

    if [ "\\\$1" == "-s" ]; then
        notebook_start
    elif [ "\\\$1" == "-q" ]; then
        notebook_quit
    elif [ "\\\$1" == "-c" ]; then
        notebook_status
    elif [ "\\\$1" == "-h" ]; then
        notebook_usage
    else
        notebook_usage
        exit \\\$JUPYTER_ERR
    fi

    exit \\\$JUPYTER_OK
}

jupyter_notebook \\\$@
EOF2
chmod 755 /usr/bin/hpa-jupyter-notebook.sh
EOF1
   chmod 755 /tmp/jupyter_compute.sh
}

############################################################
################### Jupyter notebook end ###################
############################################################

############################################################
####################### LDAP start #########################
############################################################

write_ldap () {
   cat >> /tmp/ldap.sh <<EOF1
#!/bin/sh

DOMAIN=\$1
LDAPSERVER=\$2
ROOTPWD=\$3

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo | tee -a \${LOG}
echo "Argument 1 DOMAIN: \${DOMAIN}" | tee -a \${LOG}
echo "Argument 2 LDAPSERVER: \${LDAPSERVER}" | tee -a \${LOG}
echo "Argument 3 ROOTPWD: \${ROOTPWD}" | tee -a \${LOG}
echo | tee -a \${LOG}


case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install ipa-client >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install freeipa-client >> \${LOG} 2>&1
;;
esac

timeout 60 ipa-client-install -p admin -w \${ROOTPWD} --force-join --no-ntp --domain=\${DOMAIN}  --server=\${LDAPSERVER} --unattended --mkhomedir --force-join >> \${LOG} 2>&1

EOF1
   chmod 755 /tmp/ldap.sh
}

write_ldap_howto () {
   cat >> /tmp/ldap_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_LDAP.sh <<EOF2
#!/bin/sh

echo "Executing:"
echo "   ipa --version"
ipa --version
EOF2
   chmod 755 ~/HowTo_LDAP.sh
EOF1
   chmod 755 /tmp/ldap_howto.sh
}

############################################################
######################## LDAP end ##########################
############################################################

############################################################
################## Licensescheduler start ##################
############################################################

write_licensescheduler_master () {
   cat >> /tmp/licensescheduler_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

. \${LSF_TOP}/conf/profile.lsf
LSF_TOP=\$1

cd /tmp
echo "Downloading lsf10.1_licsched_lnx310-x64.tar.Z from box" | tee -a \${LOG}
curl -Lo lsf10.1_licsched_lnx310-x64.tar.Z https://ibm.box.com/shared/static/hxtzivjdrtiimwe6tmu8ufm3mq3gtl75.z >> \${LOG} 2>&1
tar xzf lsf10.1_licsched_lnx310-x64.tar.Z
echo "Installing Licensescheduler" | tee -a \${LOG}
cd lsf10.1_licsched_linux3.10-glibc2.17-x86_64
cat >> setup.config <<EOF2
SILENT_INSTALL="Y"
EOF2
./setup -f setup.config >> \${LOG} 2>&1

echo "Downloading lsf10.1_lnx310-lib217-x86_64-600490.tar.Z from box" | tee -a \${LOG}
curl -Lo lsf10.1_lnx310-lib217-x86_64-600490.tar.Z https://ibm.box.com/shared/static/fmglqazikgsnk0l1lb81xnmp2vii3ihy.z >> \${LOG} 2>&1
echo "Applying patch" | tee -a \${LOG}
\${LSF_TOP}/10.1/install/patchinstall --silent lsf10.1_lnx310-lib217-x86_64-600490.tar.Z >> \${LOG} 2>&1

echo "Modifying LSF configuration" | tee -a \${LOG}
# Comment IN for LS Standard Edition, comment OUT for LS Basic Edition
cat >> \${LSF_TOP}/conf/ls.entitlement <<EOF2
LS_Standard   10.1   ()   ()   ()   ()   18b1928f13939bd17bf25e09a2dd8459f238028f
EOF2

LIC_SCHED_CONFIG="\${LSF_TOP}/conf/lsf.licensescheduler"
cp \${LIC_SCHED_CONFIG} \${LIC_SCHED_CONFIG}.orig
cat \${LIC_SCHED_CONFIG}.orig | sed -n '1,/HOSTS/'p | egrep -v ^HOSTS >> \${LIC_SCHED_CONFIG}
echo "HOSTS = \${HOSTNAME}" >> \${LIC_SCHED_CONFIG}
cat \${LIC_SCHED_CONFIG}.orig | sed -n '/HOSTS/,$'p | egrep -v ^HOSTS >> \${LIC_SCHED_CONFIG}

cp \${LIC_SCHED_CONFIG} \${LIC_SCHED_CONFIG}.orig
cat \${LIC_SCHED_CONFIG}.orig | sed -n '1,/ADMIN/'p | egrep -v ^ADMIN >> \${LIC_SCHED_CONFIG}
echo "ADMIN =  lsfadmin" >> \${LIC_SCHED_CONFIG}
cat \${LIC_SCHED_CONFIG}.orig | sed -n '/ADMIN/,$'p | egrep -v ^ADMIN >> \${LIC_SCHED_CONFIG}

echo "LSF_LIC_SCHED_HOSTS=\${HOSTNAME}" >> \${LSF_TOP}/conf/lsf.conf

cat << EOF2 >> \${LIC_SCHED_CONFIG}
Begin Parameters
PORT = 9581
HOSTS = \${HOSTNAME}
ADMIN =  lsfadmin
LM_STAT_INTERVAL = 5
LMSTAT_PATH = /usr/bin
End Parameters

Begin Projects
PROJECTS  
myProject1
myProject2
End Projects

Begin Clusters
CLUSTERS
onprem
End Clusters
Begin ServiceDomain
NAME = ServiceDomain1
LIC_SERVERS = ((1234@\${HOSTNAME}))
End ServiceDomain

Begin ServiceDomain
NAME = ServiceDomain2
LIC_SERVERS = ((5678@\${HOSTNAME}))
End ServiceDomain

Begin Feature
NAME = msc_1
CLUSTER_MODE=Y
CLUSTER_DISTRIBUTION=ServiceDomain1(onprem 100)
End Feature

Begin Feature
NAME = msc_A
DISTRIBUTION = ServiceDomain2(myProject1 10 myProject2 10)
End Feature
NAME = msc_B
DISTRIBUTION = ServiceDomain2(myProject1 10 myProject2 20)
End Feature
Begin Feature
NAME = msc_C
DISTRIBUTION = ServiceDomain2(myProject1 10 myProject2 50)
End Feature
EOF2

if test "\${REGION}" = "onprem"
then
   echo "Restarting LSF" | tee -a \${LOG}
   RET=\`systemctl status lsfd\`
   if test "\${RET}" = ""
   then
      . \${LSF_TOP}/conf/profile.lsf
      lsf_daemons restart
   else
      systemctl restart lsfd
   fi
fi
EOF1
   chmod 755 /tmp/licensescheduler_master.sh
}

write_licensescheduler_howto () {
   cat >> /tmp/licensescheduler_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Licensescheduler.sh <<EOF2
#!/bin/sh

USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "Executing:"
   echo "   sudo -i -u lsfadmin blinfo"
   echo
   sudo -i -u lsfadmin blinfo
   echo "   sudo -i -u lsfadmin blstat"
   echo
   sudo -i -u lsfadmin blstat
;;
*)
   echo "Executing:"
   echo "   blinfo"
   echo
   blinfo
   echo "   blstat"
   echo
   blstat
;;
esac
EOF2
   chmod 755 ~/HowTo_Licensescheduler.sh
EOF1
   chmod 755 /tmp/licensescheduler_howto.sh
}

############################################################
################### Licensescheduler end ###################
############################################################

############################################################
###################### LS-DYNA start #######################
############################################################

write_lsdyna_compute () {
   cat >> /tmp/lsdyna_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Downloading LS-DYNA" | tee -a \${LOG}
cd /usr/bin
curl -u user:computer -LO https://ftp.lstc.com/user/ls-dyna/R13.1.0/linx.64/ls-dyna_smp_s_R13_1_0_centos79_intel190.tar.gz_extractor.sh >> \${LOG} 2>&1
echo "Installing LS-DYNA" | tee -a \${LOG}
chmod 755 ls-dyna_smp_s_R13_1_0_centos79_intel190.tar.gz_extractor.sh
./ls-dyna_smp_s_R13_1_0_centos79_intel190.tar.gz_extractor.sh --skip-license >> \${LOG} 2>&1
rm -rf ls-dyna_smp_s_R13_1_0_centos79_intel190.tar.gz_extractor.sh
EOF1
   chmod 755 /tmp/lsdyna_compute.sh
}

write_lsdyna_howto () {
   cat >> /tmp/lsdyna_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_LS-DYNA.sh <<EOF2
#!/bin/sh

USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "Executing:"
   echo "   sudo -i -u lsfadmin bsub -I ls-dyna_smp_s_R13_1_0_x64_centos79_ifort190"
   echo
   sudo -i -u lsfadmin bsub -I ls-dyna_smp_s_R13_1_0_x64_centos79_ifort190
;;
*)
   echo "Executing:"
   echo "   bsub ls-dyna_smp_s_R13_1_0_x64_centos79_ifort190"
   echo
   bsub -I ls-dyna_smp_s_R13_1_0_x64_centos79_ifort190
;;
esac
EOF2
   chmod 755 ~/HowTo_LS-DYNA.sh
EOF1
   chmod 755 /tmp/lsdyna_howto.sh
}

############################################################
####################### LS-DYNA end ########################
############################################################

############################################################
######################## LSF start #########################
############################################################

write_lsf () {
   cat >> /tmp/lsf.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

ROLE=\$1
LSF_TOP=\$2
LSF_ENTITLEMENT=\$3
LSF_CLUSTER_NAME=\$4
LSF_MASTER=\$5

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 LSF_ENTITLEMENT: \${LSF_ENTITLEMENT}" | tee -a \${LOG}
echo "Argument 3 LSF_CLUSTER_NAME: \${LSF_CLUSTER_NAME}" | tee -a \${LOG}
echo "Argument 4 LSF_MASTER: \${LSF_MASTER}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "Install some RPMs" | tee -a \${LOG}
   yum -y --nogpgcheck install java libnsl ed >> \${LOG} 2>&1
;;
*debian*)
   echo "Install some packages" | tee -a \${LOG}
   chmod 755 /lib/x86_64-linux-gnu/libc.so.6
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install default-jre >> \${LOG} 2>&1
;;
esac

cd /tmp
echo "Downloading LSF tarballs from box" | tee -a \${LOG}
echo "   lsf10.1_lsfinstall.tar.Z" | tee -a \${LOG}
curl -Lo lsf10.1_lsfinstall.tar.Z https://ibm.box.com/shared/static/p0ys30wnukfru4csaeyl433uu0l4rats.z >> \${LOG} 2>&1
echo "   lsf10.1_lnx310-lib217-x86_64-601547.tar.Z" | tee -a \${LOG}
curl -Lo lsf10.1_lnx310-lib217-x86_64-601547.tar.Z https://ibm.box.com/shared/static/7g1it2xkskcq1lwbccq6o6fuipewcz2x.z >> \${LOG} 2>&1
echo "   lsf10.1_lnx310-lib217-x86_64.tar.Z" | tee -a \${LOG}
curl -Lo lsf10.1_lnx310-lib217-x86_64.tar.Z https://ibm.box.com/shared/static/9tsvu1spbbaexqpbassz91zgw5icjzc2.z >> \${LOG} 2>&1
echo "   rc_scripts.tar.Z" | tee -a \${LOG}
curl -Lo rc_scripts.tar.Z https://ibm.box.com/shared/static/eqc6scn8hkg47qbzemgvg7ucltlq32ce.z >> \${LOG} 2>&1

echo "Unpack lsf10.1_lsfinstall.tar.Z" | tee -a \${LOG}
tar xzf lsf10.1_lsfinstall.tar.Z >> \${LOG} 2>&1
cd /tmp/lsf10.1_lsfinstall
echo "LSF_Standard 10.1 () () () pa \${LSF_ENTITLEMENT}" >> /tmp/lsf_std_entitlement.dat

cat >> /tmp/install.config <<EOF2
LSF_TOP="\${LSF_TOP}"
LSF_ADMINS="lsfadmin"
LSF_ENTITLEMENT_FILE="/tmp/lsf_std_entitlement.dat"
ENABLE_DYNAMIC_HOSTS="Y"
ENABLE_STREAM="Y"
LSF_CLUSTER_NAME="\${LSF_CLUSTER_NAME}"
EOF2

case \${ROLE} in
master)
   cat >> /tmp/install.config <<EOF2
LSF_MASTER_LIST="\${LSF_MASTER}"
EOF2
;;
compute)
   if test "\`egrep \${LSF_MASTER} /etc/hosts\`" = ""
   then
      echo "11.22.33.44  \${LSF_MASTER}" >> /etc/hosts
   fi
   cat >> /tmp/install.config <<EOF2
LSF_SERVER_HOSTS="\${LSF_MASTER}"
LSF_LIM_PORT=7869
LSF_LOCAL_RESOURCES="[resource define_ncpus_threads]"
EOF2
;;
esac

cat >> /tmp/answer <<EOF2
1

EOF2

echo "Installing LSF" | tee -a \${LOG}
cd /tmp/lsf10.1_lsfinstall


case \${ROLE} in
compute)
   SLAVE="-s"
;;
esac

cat /tmp/answer | ./lsfinstall \${SLAVE} -f /tmp/install.config >> \${LOG} 2>&1

ln -s \${LSF_TOP}/conf/profile.lsf /etc/profile.d/lsf.sh
SAVE="\${LSF_TOP}"   
if test -f \${LSF_TOP}/conf/profile.lsf
then
   . \${LSF_TOP}/conf/profile.lsf
fi
LSF_TOP="\${SAVE}"

echo "Installing LSF patch" | tee -a \${LOG}
\${LSF_TOP}/10.1/install/patchinstall --silent /tmp/lsf10.1_lnx310-lib217-x86_64-601547.tar.Z >> \${LOG} 2>&1
if test -d \${LSF_TOP}/10.1/resource_connector/ibmcloudgen2/scripts
then
   echo "Extracting rc_scripts.tar.Z" | tee -a \${LOG}
   cd \${LSF_TOP}/10.1/resource_connector/ibmcloudgen2/scripts
   rm -rf *
   tar xzf /tmp/rc_scripts.tar.Z
   chmod 755 *
fi

cp \${LSF_TOP}/10.1/install/instlib/startup.svr4 \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/lsf_daemons
sed -i s#"@LSF_CONF@"#"\${LSF_TOP}/conf/lsf.conf"#g \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/lsf_daemons
sed -i s/"#\!\/bin\/sh"/"#\!\/bin\/sh\nsleep 10"/g \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/lsf_daemons

echo "Modifying LSF configuration" | tee -a \${LOG}

if test -f \${LSF_TOP}/conf/lsbatch/\${LSF_CLUSTER_NAME}/configdir/lsb.resources
then
   cat >> \${LSF_TOP}/conf/lsbatch/\${LSF_CLUSTER_NAME}/configdir/lsb.resources <<EOF2

Begin Limit
Name = masterHost
HOSTS = \${HOSTNAME}
SLOTS = 0
End Limit
EOF2
fi

if test -f \${LSF_TOP}/conf/lsbatch/\${LSF_CLUSTER_NAME}/configdir/lsb.queues
then
   cat >> \${LSF_TOP}/conf/lsbatch/\${LSF_CLUSTER_NAME}/configdir/lsb.queues <<EOF2
Begin Queue
QUEUE_NAME       = normal
RES_REQ          = select[type==any] affinity[thread]
PRIORITY         = 40
INTERACTIVE      = YES
End Queue
EOF2
fi

if test -f \${LSF_TOP}/conf/lsf.conf
then
   cat >> \${LSF_TOP}/conf/lsf.conf <<EOF2
LSF_NIOS_PORT_RANGE=11000-11019
LSB_SUB_COMMANDNAME=y
LSF_PROCESS_TRACKING=Y
LSF_LINUX_CGROUP_ACCT=Y
#LSB_RESOURCE_ENFORCE="cpu memory"
EOF2
fi

echo "Running hostsetup" | tee -a \${LOG}
\${LSF_TOP}/10.1/install/hostsetup --top=\${LSF_TOP} --boot=y >> \${LOG} 2>&1

if test "\${REGION}" = "onprem"
then
   echo "Starting LSF" | tee -a \${LOG}
   systemctl enable lsfd >> \${LOG} 2>&1
   systemctl start lsfd >> \${LOG} 2>&1
else
   # Will enable and start LSF via postboot
   systemctl disable lsfd-lim >> \${LOG} 2>&1
   systemctl disable lsfd-sbd >> \${LOG} 2>&1
   systemctl disable lsfd-res >> \${LOG} 2>&1
   systemctl disable lsfd >> \${LOG} 2>&1
fi
EOF1
   chmod 755 /tmp/lsf.sh
}

############################################################
######################### LSF end ##########################
############################################################

############################################################
######################## LWS start #########################
############################################################

write_lws_master () {
   SHARED=$1
   cat >> /tmp/lws_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

case \${ID_LIKE} in
*debian*)
   echo "LWS is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Installing LWS" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

cd /tmp
echo "Downloading LWS from box" | tee -a \${LOG}
echo "   lws10.1.0.14preview_linux-x86_64.tar.Z" | tee -a \${LOG}
curl -Lo lws10.1.0.14preview_linux-x86_64.tar.Z https://ibm.box.com/shared/static/269ljfp6s5001a0hlszg4wpykv2ygzp1.z >> \${LOG} 2>&1
echo "   lsf" | tee -a \${LOG}
cd /usr/bin
curl -Lo lsf https://ibm.box.com/shared/static/s8pwsnjn0laji3b5zmiqpuz0tejgskq8 >> \${LOG} 2>&1
chmod 755 lsf

echo "Installing LWS" | tee -a \${LOG}
cd /tmp
tar xzf lws10.1.0.14preview_linux-x86_64.tar.Z >> \${LOG} 2>&1
cd /tmp/lws10.1.0.14_linux-x86_64
sed -i s/"HTTP_MODE_FRESH_INSTALL=\"https\""/"HTTP_MODE_FRESH_INSTALL=\"http\""/g lwsinstall.sh
sed -i s/"4096"/"0"/g lwsinstall.sh
. \${LSF_TOP}/conf/profile.lsf
./lwsinstall.sh -y -s >> \${LOG} 2>&1

cat >> /usr/bin/lwsservice.sh <<EOF2
#!/bin/sh
. /opt/ibm/lsfsuite/ext/profile.platform
echo lwsstart.sh | at now
exit 0
EOF2
chmod 755 /usr/bin/lwsservice.sh

cat >> /etc/systemd/system/lws.service <<EOF2
[Unit]
Description=IBM Spectrum LSF Web Service
After=network.target nfs.service autofs.service gpfs.service

[Service]
Type=forking
ExecStart=/usr/bin/lwsservice.sh

[Install]
WantedBy=multi-user.target
EOF2

systemctl enable lws
systemctl start lws

cp lsf /usr/bin/
EOF1
   chmod 755 /tmp/lws_master.sh
}

write_lws_howto () {
   SHARED=$1
   cat >> /tmp/lws_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_LWS.sh <<EOF2
#!/bin/sh

echo "Running:"
echo "   lsf cluster logon --username lsfadmin --url http://localhost:8088"
echo "   lsf lsid"
echo
lsf cluster logon --username lsfadmin --url http://localhost:8088
lsf lsid
EOF2
   chmod 755 ~/HowTo_LWS.sh
EOF1
   chmod 755 /tmp/lws_howto.sh
}

############################################################
######################### LWS end ##########################
############################################################

############################################################
################## MATLAB Runtime start ####################
############################################################

write_matlab_master () {
   SHARED=$1
   cat >> /tmp/matlab_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

SHARED=\$1

echo | tee -a \${LOG}
echo "Argument 1 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Installing MATLAB-Runtime" | tee -a \${LOG}
rm -rf /tmp/matlab_install
mkdir -p /tmp/matlab_install
cd /tmp/matlab_install
curl -LO https://ssd.mathworks.com/supportfiles/downloads/R2023b/Release/1/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023b_Update_1_glnxa64.zip >> \${LOG} 2>&1
unzip MATLAB_Runtime_R2023b_Update_1_glnxa64.zip >> \${LOG} 2>&1
mkdir -p ${SHARED}/MATLAB
./install -agreeToLicense yes -destinationFolder ${SHARED}/MATLAB >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/matlab_master.sh
}

write_matlab_howto () {
   SHARED=$1
   cat >> /tmp/matlab_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_MATLAB_Runtime.sh <<EOF2
#!/bin/sh

echo "Execute:"
echo "   sudo -i -u lsfadmin bsub -I ls -al ${SHARED}/MATLAB/R2023b"
echo
sudo -i -u lsfadmin bsub -I ls -al ${SHARED}/MATLAB/R2023b
EOF2
   chmod 755 ~/HowTo_MATLAB_Runtime.sh
EOF1
   chmod 755 /tmp/matlab_howto.sh
}

############################################################
################### MATLAB Runtime end #####################
############################################################

############################################################
################### Monitoring start #######################
############################################################

write_monitoring () {
   SHARED=$1
   cat >> /tmp/monitoring.sh <<EOF1
#!/bin/sh

. /etc/os-release

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

case \${ID_LIKE} in
*rhel*|*fedora*)

   RELEASE=\`uname -r\`
   case \${RELEASE} in
   5.14.0-362.8.1.el9_3.x86_64)
      # Almalinux9.3
      #yum -y install https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/kernel-headers-5.14.0-362.8.1.el9_3.x86_64.rpm >> \${LOG} 2>&1
      yum -y install https://ibm.box.com/shared/static/ymuzzvgw43rblpjhvpxn8y829tl68a79.rpm >> \${LOG} 2>&1
      #yum -y install https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/kernel-devel-5.14.0-362.8.1.el9_3.x86_64.rpm >> \${LOG} 2>&1
      yum -y install https://ibm.box.com/shared/static/bvcj7kgkzvo89dwizk4urc4hkf51xy8p.rpm >> \${LOG} 2>&1
   ;;
   5.14.0-252.el9.x86_64)
      # CentOS9 stream
      # Too dangerous, node will never come back...
      # yum -y install kernel-devel kernel-headers >> \${LOG} 2>&1
   ;;
   esac
   curl -s -o /etc/yum.repos.d/draios.repo https://download.sysdig.com/stable/rpm/draios.repo >> \${LOG} 2>&1
   sed -i s/"gpgcheck=1"/"gpgcheck=0"/g /etc/yum.repos.d/draios.repo
#   yum -y --nogpgcheck install bison dkms draios-agent draios-agent-kmodule draios-agent-slim elfutils-libelf-devel flex kernel-devel libzstd-devel m4 openssl-devel >> \${LOG} 2>&1
   yum -y --nogpgcheck install draios-agent draios-agent-kmodule draios-agent-slim >> \${LOG} 2>&1
;;
*debian*)
   curl -s https://download.sysdig.com/DRAIOS-GPG-KEY.public | apt-key add -
   curl -o /etc/apt/sources.list.d/draios.list https://download.sysdig.com/stable/deb/draios.list >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install cpp-12 dctrl-tools dkms draios-agent draios-agent-kmodule draios-agent-slim gcc-12 gnupg libasan8 libgcc-12-dev libtsan2 >> \${LOG} 2>&1
;;
esac
EOF1
   chmod 755 /tmp/monitoring.sh
}

############################################################
#################### Monitoring end ########################
############################################################

############################################################
#################### Multicluster start ####################
############################################################

write_multicluster_master () {
   cat >> /tmp/multicluster_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
REMOTE_CLUSTERNAME=\$2
REMOTE_MASTER=\$3
REMOTE_IP=\$4

echo "Multicluster" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Modifying LSF configuration" | tee -a \${LOG}
CLUSTERNAME=\`ls \${LSF_TOP}/conf/lsf.cluster.* | awk 'BEGIN{FS="."}{print \$NF}'\`
sed -i -e s/"ClusterName"/"ClusterName Servers"/g \${LSF_TOP}/conf/lsf.shared
sed -i s/"ClusterName Servers"/"ClusterName Servers\nremote_clustername remote_master"/g \${LSF_TOP}/conf/lsf.shared
sed -i s/"\${CLUSTERNAME}"/"\${CLUSTERNAME} \${HOSTNAME}"/g \${LSF_TOP}/conf/lsf.shared
echo "11.22.33.44 remote_master" >> /etc/hosts
if test "\${REGION}" = "onprem"
then
   echo "Restarting LSF" | tee -a \${LOG}
   RET=\`systemctl status lsfd\`
   if test "\${RET}" = ""
   then
      . \${LSF_TOP}/conf/profile.lsf
      lsf_daemons restart
   else
      systemctl restart lsfd
   fi
fi
echo "Writing Multicluster watchdog" | tee -a \${LOG}
cat >> /usr/bin/mc_watchdog.sh <<EOF2
#!/bin/sh

. /var/environment.sh

# Are we onprem or in the cloud?
if test "\${REGION}" = "onprem"
then
   URL="master-ibmcloud.ddnss.org"
else
   URL="master-onprem.ddnss.org"
fi

while true
do
   if test "\\\${WITH_MULTICLUSTER}" = "Y"
   then
      OTHER_CLUSTERNAME=\\\`timeout 2 ssh \\\${URL} ". \\\${LSF_TOP}/conf/profile.lsf ; lsid 2>/dev/null" | fgrep "My cluster name is" | awk '{print \\\$5}'\\\`
      MC_CONFIG=\\\`egrep remote \\\${LSF_TOP}/conf/lsf.shared\\\`
      OTHER_UP=\\\`timeout 2 ssh \\\${URL} hostname 2>/dev/null | egrep master\\\`
      if test "\\\${OTHER_CLUSTERNAME}" != "" -a "\\\${MC_CONFIG}" != ""
      then
         # Wait for postboot.sh to be finished
         if test "\\\${REGION}" != "onprem"
         then
            RET=""
            while test "\\\${RET}" = ""
            do
               RET=\\\`egrep NEW_WRITTEN_BY_POSTBOOT /etc/hosts\\\`
               sleep 2
            done
         fi
         OTHER_EXT_IP=\\\`ssh \\\${URL} curl ifconfig.me 2>/dev/null\\\`
         OLD_EXT_IP=\\\$OTHER_EXT_IP
         OTHER_MASTERNAME=\\\`ssh \\\${URL} hostname -s 2>/dev/null\\\`
         OLD_MASTERNAME=\\\$OTHER_MASTERNAME
         OLD_CLUSTERNAME=\\\$OTHER_CLUSTERNAME
         echo "Changing LSF MC config"
         echo "   OTHER_EXT_IP is \\\$OTHER_EXT_IP"
         echo "   OTHER_CLUSTERNAME is \\\$OTHER_CLUSTERNAME"
         echo "   MC_CONFIG is \\\$MC_CONFIG"
         echo "   OTHER_MASTERNAME is \\\$OTHER_MASTERNAME"
         echo "\\\$OTHER_EXT_IP \\\$OTHER_MASTERNAME" >> /etc/hosts
         sed -i -e s/"remote_clustername"/"\\\${OTHER_CLUSTERNAME}"/g \\\\
            -e s/"remote_master"/"\\\${OTHER_MASTERNAME}"/g \\\\
            \\\${LSF_TOP}/conf/lsf.shared
         RET=\\\`egrep SNDJOBS_TO \\\${LSF_TOP}/conf/lsbatch/cluster-\\\${REGION}/configdir/lsb.queues\\\`
         if test "\\\${RET}" = ""
         then
            sed -i s/"QUEUE_NAME       = normal"/"QUEUE_NAME       = normal\nSNDJOBS_TO       = normal@\\\${OTHER_CLUSTERNAME}\nRCVJOBS_FROM      = \\\${OTHER_CLUSTERNAME}\nMAX_RSCHED_TIME  = 100"/g \\\${LSF_TOP}/conf/lsbatch/cluster-\\\${REGION}/configdir/lsb.queues
         fi
         echo "  Restarting LSF"
         systemctl restart lsfd
      fi
      #if test "\\\${OTHER_UP}" = "" -a "\\\${MC_CONFIG}" = "" -a "\\\${OLD_EXT_IP}" != ""
      #then
      #   echo "Changing back LSF MC config"
      #   echo "   OLD_EXT_IP is \\\$OLD_EXT_IP"
      #   echo "   OLD_CLUSTERNAME is \\\$OLD_CLUSTERNAME"
      #   echo "   OLD_MASTERNAME is \\\$OLD_MASTERNAME"
      #   egrep -v \\\$OLD_EXT_IP /etc/hosts >> /etc/hosts.new
      #   mv /etc/hosts.new /etc/hosts
      #   sed -i -e s/"\\\${OLD_CLUSTERNAME}"/"remote_clustername"/g \\\\
      #      -e s/"\\\${OLD_MASTERNAME}"/"remote_master"/g \\\\
      #      \\\${LSF_TOP}/conf/lsf.shared
      #   echo "  Restarting LSF"
      #   systemctl restart lsfd
      #fi
      sleep 30
   fi
done
EOF2
chmod 755 /usr/bin/mc_watchdog.sh

cat >> /etc/systemd/system/mc_watchdog.service <<EOF2
[Unit]
Description=LSF Multicluster watchdog

[Service]
Type=simple
ExecStart=/usr/bin/mc_watchdog.sh
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=mc_watchdog

[Install]
WantedBy=multi-user.target
EOF2

echo "Starting Multicluster watchdog" | tee -a \${LOG}
systemctl enable mc_watchdog
systemctl start mc_watchdog
EOF1
   chmod 755 /tmp/multicluster_master.sh
}

write_multicluster_howto () {
   cat >> /tmp/multicluster_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Multicluster.sh <<EOF2
#!/bin/sh

echo "Executing:"
echo "   lsclusters"
echo
lsclusters
EOF2
   chmod 755 ~/HowTo_Multicluster.sh
EOF1
   chmod 755 /tmp/multicluster_howto.sh
}

############################################################
##################### Multicluster end #####################
############################################################

############################################################
###################### Nextflow start ######################
############################################################

write_nextflow_master () {
   cat >> /tmp/nextflow_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo "Modifying LSF configuration" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

CLUSTERNAME=\`ls \${LSF_TOP}/conf/lsf.cluster.* | awk 'BEGIN{FS="."}{print \$NF}'\`
echo "   Allow root" | tee -a \${LOG}
echo "LSF_ROOT_USER=Y" >> ${LSF_TOP}/conf/lsf.conf
#echo "   Give all nodes only 1 jobslot" | tee -a \${LOG}
#sed -i s/"default    !"/"default    1"/g \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.hosts
#echo "   Create (artificial) jobstarter" | tee -a \${LOG}
#cat >> \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/bin/mystarter <<EOF2
##!/bin/sh
#sleep 20
#\\\$*
#sleep 20
#EOF2
#chmod 755 \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/bin/mystarter
#sed -i s/"QUEUE_NAME       = normal"/"QUEUE_NAME       = normal\nJOB_STARTER        = mystarter"/g \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.queues

if test "\${REGION}" = "onprem"
then
   echo "Restarting LSF" | tee -a \${LOG}
   systemctl restart lsfd >> \${LOG} 2>&1
fi

echo "Installing Java" | tee -a \${LOG}
case \\\${ID_LIKE} in
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install default-jre >> \${LOG} 2>&1
;;
esac

echo "Installing Nextflow" | tee -a \${LOG}
cd /usr/bin; (curl -s https://get.nextflow.io | bash ) | tee -a \${LOG}
EOF1
   chmod 755 /tmp/nextflow_master.sh
}

write_nextflow_compute () {
   cat >> /tmp/nextflow_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Pulling image rnaseq-nf for root" | tee -a \${LOG}
podman pull docker.io/nextflow/rnaseq-nf >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/nextflow_compute.sh
}

write_nextflow_howto () {
   cat >> /tmp/nextflow_howto.sh <<EOF1
#!/bin/sh

SHARED=\$1
LSF_TOP=\$2

cat >> ~/HowTo_Nextflow.sh <<EOF2
#!/bin/sh

. /etc/os-release
. /var/environment.sh

echo "Clone Nextflow training"
RET=\\\`which git 2>/dev/null\\\`
if test "\\\${RET}" = ""
then
   case \\\${ID_LIKE} in
   *rhel*|*fedora*)
      yum -y --nogpgcheck install git 1>/dev/null 2>/dev/null
   ;;
   *debian*)
      export DEBIAN_FRONTEND=noninteractive
      apt -y -qq install git 1>/dev/null 2>/dev/null
   ;;
   esac
fi
mkdir -p \${SHARED}/nextflow
cd \${SHARED}/nextflow
git clone https://github.com/nextflow-io/training.git 1>/dev/null 2>/dev/null
echo "Modify parameters"
cd \${SHARED}/nextflow/training/nf-training/
echo "   Change container repository"
sed -i s/"nextflow\/rnaseq-nf"/"docker.io\/nextflow\/rnaseq-nf"/g nextflow.config
echo "   Enable docker"
echo "docker.enabled = true" >> nextflow.config
echo "   Make lsf the default executor"
if test -f \${LSF_TOP}/conf/lsf.conf
then
   SCHEDULER="lsf"
else
   SCHEDULER="slurm"
fi
cat >> nextflow.config <<EOF3
process {
    executor="\\\${SCHEDULER}"
}
EOF3

echo "   Create HowTo_Nextflow_training.sh"
cat >> ~/HowTo_Nextflow_training.sh <<EOF3
#!/bin/sh

. \${LSF_TOP}/conf/profile.lsf

cd \${SHARED}/nextflow/training/nf-training/
for N in 1 2 3 4 5 6 7
do
   echo ""
   echo "Executing script\\\\\\\${N}.nf"
   echo "===================="
   nextflow script\\\\\\\${N}.nf
done

firefox \${SHARED}/nextflow/training/nf-training/results/multiqc_report.html &
EOF3
   chmod 755 ~/HowTo_Nextflow_training.sh
echo
echo "Next step: execute ~/HowTo_Nextflow_training.sh"
echo
EOF2
chmod 755 ~/HowTo_Nextflow.sh
EOF1
   chmod 755 /tmp/nextflow_howto.sh
}

############################################################
######################## Nextflow end ######################
############################################################

############################################################
######################## NFS start #########################
############################################################

write_nfs_master () {
   cat >> /tmp/nfs_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

NFS_SHARES=\$*

echo | tee -a \${LOG}
echo "Arguments NFS_SHARES: \${NFS_SHARES}" | tee -a \${LOG}
echo | tee -a \${LOG}

for SHARE in \${NFS_SHARES}
do
   mkdir -p \${SHARE}
   chmod 777 \${SHARE}
   echo "\${SHARE} *(rw,sync,no_root_squash)" >> /etc/exports
done

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install nfs-utils >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install nfs-kernel-server nfs-common >> \${LOG} 2>&1
;;
esac

systemctl enable nfs-server >> \${LOG} 2>&1
exportfs -a >> \${LOG} 2>&1
EOF1
   chmod 755  /tmp/nfs_master.sh
}

write_nfs_compute () {
   cat >> /tmp/nfs_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

NFS_SERVER=\$1
NFS_SHARES=\`echo \$* | awk '{for(i=2;i<=NF;i++){printf("%s ",\$i)}}'\`

echo | tee -a \${LOG}
echo "Argument 1 NFS_SERVER: \${NFS_SERVER}" | tee -a \${LOG}
echo "Argument * NFS_SHARES: \${NFS_SHARES}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install nfs-common >> \${LOG} 2>&1
;;
esac

for SHARE in \${NFS_SHARES}
do
   mkdir -p \${SHARE}
   chmod 777 \${SHARE}
   echo "\${NFS_SERVER}:\${SHARE} \${SHARE} nfs soft,rw,fg,nfsvers=4 0 0" >> /etc/fstab
done

if test "\${REGION}" = "onprem"
then
   ALL_MOUNTS_OK="N"
   while test "\${ALL_MOUNTS_OK}" != "Y"
   do
      mount -a >> \${LOG} 2>&1
      ALL_MOUNTS_OK="Y"
      for SHARE in \${NFS_SHARES}
      do
         RET=\`mount | fgrep \${SHARE}\`
         if test "\${RET}" = ""
         then
            ALL_MOUNTS_OK="N"
         fi
      done
      sleep 2
   done
fi
EOF1
   chmod 755  /tmp/nfs_compute.sh
}

############################################################
######################### NFS end ##########################
############################################################

############################################################
####################### Octave start #######################
############################################################

write_octave_master () {
   cat >> /tmp/octave_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

LSB_APPLICATIONS=\`ls \${LSF_TOP}/conf/lsbatch/*/configdir/lsb.applications\`
RET=\`egrep octave \${LSB_APPLICATIONS}\`
if test "\${RET}" = ""
then
   echo "Modify LSF configuration" | tee -a \${LOG}
   cat >> \${LSB_APPLICATIONS} <<EOF2

Begin Application
NAME = octave
RES_REQ = span[hosts=1]
CONTAINER = podman[image(docker.io/gnuoctave/octave) options(--rm)]
DESCRIPTION = Octave
EXEC_DRIVER = context[user(default)] \
   starter[\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/docker-starter.py] \
   controller[\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/docker-control.py]
End Application
EOF2
   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd\`
      if test "\${RET}" = ""
      then
         . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
EOF1
   chmod 755 /tmp/octave_master.sh
}

write_octave_compute () {
   cat >> /tmp/octave_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Pulling image octave for lsfadmin" | tee -a \${LOG}
sudo -i -u lsfadmin podman pull docker.io/gnuoctave/octave >> \${LOG} 2>&1

EOF1
   chmod 755 /tmp/octave_compute.sh
}

write_octave_howto () {
   cat >> /tmp/octave_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Octave.sh <<EOF2
#!/bin/sh



echo "Submitting octave job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -app octave -Ip octave -W"
   echo
   sudo -i -u lsfadmin bsub -app octave -Ip octave -W
;;
*)
   echo "   bsub -app octave -Ip octave -W"
   echo
   bsub -app octave -Ip octave -W
;;
esac
EOF2
   chmod 755 ~/HowTo_Octave.sh
EOF1
   chmod 755 /tmp/octave_howto.sh
}

############################################################
######################## Octave end ########################
############################################################

###########################################################
##################### OpenFOAM start ######################
###########################################################

write_openfoam_master () {
   cat >> /tmp/openfoam_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

OPENFOAM_BIN="openfoam11-linux"
OPENFOAM_IMAGE="openfoam11-paraview510"

echo "Installing \${OPENFOAM_BIN}" | tee -a \${LOG}
cd /usr/bin
curl -LO http://dl.openfoam.org/docker/\${OPENFOAM_BIN} >> \${LOG} 2>&1
chmod 755 /usr/bin/\${OPENFOAM_BIN}

echo "Modifying LSF configuration" | tee -a \${LOG}
RET=\`egrep LSF_ROOT_USER \${LSF_TOP}/conf/lsf.conf\`
if test "\${RET}" = ""
then
   echo "LSF_ROOT_USER=Y" >> \${LSF_TOP}/conf/lsf.conf
   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd 2>/dev/null\`
      if test "\${RET}" = ""
      then
         . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
echo "Pulling openfoam image" | tee -a \${LOG}
podman pull docker.io/openfoam/\${OPENFOAM_IMAGE}:latest >> \${LOG} 2>&1

mkdir -p \${SHARED}/openfoam
chmod 777 \${SHARED}/openfoam
echo "Writing \${SHARED}/openfoam/input.txt" | tee -a \${LOG}
cat >> \${SHARED}/openfoam/input.txt <<EOF2
mkdir -p \\\${FOAM_RUN}
cd \\\$FOAM_RUN
cp -r \\\${FOAM_TUTORIALS}/incompressibleFluid/pitzDailySteady .
cd pitzDailySteady
blockMesh
simpleFoam
exit
EOF2
echo "Writing \${SHARED}/openfoam/paraFoam.txt" | tee -a \${LOG}
cat >> \${SHARED}/openfoam/paraFoam.txt <<EOF2
cd \\\$FOAM_RUN
cd pitzDailySteady
paraFoam
EOF2

echo "Writing \${SHARED}/openfoam/run_paraview_root.sh" | tee -a \${LOG}
cat >> \${SHARED}/openfoam/run_paraview_root.sh <<EOF2
#!/bin/sh
cat \${SHARED}/openfoam/paraFoam.txt | openfoam11-linux -x -d \${SHARED}/openfoam
EOF2
chmod 755 \${SHARED}/openfoam/run_paraview_root.sh
echo "Writing \${SHARED}/openfoam/run_openfoam_root.sh" | tee -a \${LOG}
cat >> \${SHARED}/openfoam/run_openfoam_root.sh <<EOF2
#!/bin/sh
. \${LSF_TOP}/conf/profile.lsf
bsub -Ip "cat \${SHARED}/openfoam/input.txt | openfoam11-linux -x -d \${SHARED}/openfoam"
EOF2
chmod 755 \${SHARED}/openfoam/run_openfoam_root.sh
EOF1
   chmod 755 /tmp/openfoam_master.sh
}

write_openfoam_compute () {
   cat >> /tmp/openfoam_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

OPENFOAM_BIN="openfoam11-linux"
OPENFOAM_IMAGE="openfoam11-paraview510"

echo "Distributing \${OPENFOAM_BIN}" | tee -a \${LOG}
cd /usr/bin
curl -LO http://dl.openfoam.org/docker/\${OPENFOAM_BIN} >> \${LOG} 2>&1
chmod 755 /usr/bin/\${OPENFOAM_BIN}
podman pull docker.io/openfoam/\${OPENFOAM_IMAGE}:latest >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/openfoam_compute.sh
}

write_openfoam_howto () {
   cat >> /tmp/openfoam_howto.sh <<EOF1
#!/bin/sh

SHARED=\$1

USER=\`whoami\`
case \${USER} in
root)
   SUDO=""
;;
*)
   SUDO="sudo "
;;
esac

cat >> ~/HowTo_openFOAM.sh <<EOF2
#!/bin/sh
cat <<EOF3
"Executing:
   Batch/Compute part:
   \${SUDO} \${SHARED}/openfoam/run_openfoam_root.sh

   Vizualize part:
   \${SUDO} \${SHARED}/openfoam/run_paraview_root.sh
EOF3
\${SUDO}\${SHARED}/openfoam/run_openfoam_root.sh
\${SUDO}\${SHARED}/openfoam/run_paraview_root.sh
EOF2

chmod 755 ~/HowTo_openFOAM.sh
EOF1
   chmod 755 /tmp/openfoam_howto.sh
}

###########################################################
###################### OpenFOAM end #######################
###########################################################

############################################################
###################### openMPI start #######################
############################################################

write_openmpi_master () {
   cat >> /tmp/openmpi_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   echo "MPI is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Installing openMPI" | tee -a \${LOG}

echo "Install some packages" | tee -a \${LOG}
crb enable >> \${LOG} 2>&1
yum -y --nogpgcheck install make gcc libnsl2 zlib-devel libnsl2-devel >> \${LOG} 2>&1
echo "Downloading open-mpi" | tee -a \${LOG}
curl -LO https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.1.tar.gz >> \${LOG} 2>&1
tar xvzf openmpi-5.0.1.tar.gz >> \${LOG} 2>&1
cd openmpi-5.0.1
echo "Configuring open-mpi" | tee -a \${LOG}
./configure --with-lsf=\${LSF_TOP}/10.1 --with-lsf-libdir=\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/lib >> \${LOG} 2>&1
echo "Make open-mpi" | tee -a \${LOG}
make >> \${LOG} 2>&1
echo "Make install open-mpi" | tee -a \${LOG}
make install >> \${LOG} 2>&1

echo "Compiling hello_c.c" | tee -a \${LOG}

cat >> /tmp/hello_c.c <<EOF2
#include <stdio.h>
#include "mpi.h"

int main(int argc, char* argv[])
{
    int rank, size, len;
    char version[MPI_MAX_LIBRARY_VERSION_STRING];
    char name[MPI_MAX_PROCESSOR_NAME];

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Get_processor_name(name, &len);
    printf("Hello, world, I am %d of %d on %s\n",
           rank, size, name);
    MPI_Finalize();

    return 0;
}
EOF2

mkdir -p \${SHARED}/mpi
chmod 755 \${SHARED}/mpi
mpicc -o \${SHARED}/mpi/hello_c /tmp/hello_c.c >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/openmpi_master.sh
}

write_openmpi_compute () {
   cat >> /tmp/openmpi_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   echo "MPI is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Installing openMPI" | tee -a \${LOG}

echo "Install some packages" | tee -a \${LOG}
crb enable >> \${LOG} 2>&1
yum -y --nogpgcheck install make gcc libnsl2 zlib-devel libnsl2-devel >> \${LOG} 2>&1
echo "Downloading open-mpi" | tee -a \${LOG}
curl -LO https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.1.tar.gz >> \${LOG} 2>&1
tar xvzf openmpi-5.0.1.tar.gz >> \${LOG} 2>&1
cd openmpi-5.0.1
echo "Configuring open-mpi" | tee -a \${LOG}
./configure --with-lsf=\${LSF_TOP}/10.1 --with-lsf-libdir=\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/lib >> \${LOG} 2>&1
echo "Make open-mpi" | tee -a \${LOG}
make >> \${LOG} 2>&1
echo "Make install open-mpi" | tee -a \${LOG}
make install >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/openmpi_compute.sh
}

write_openmpi_howto () {
   cat >> /tmp/openmpi_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

SHARED=\$1

echo | tee -a \${LOG}
echo "Argument 1 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

cat >> ~/HowTo_openMPI.sh <<EOF2
#!/bin/sh

SLOTS=\\\`sudo -i -u lsfadmin bhosts | egrep ok | awk 'BEGIN{S=0}{S=S+\\\$4}END{print S}'\\\`

USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "Login as lsfadmin and execute:"
   echo "   bsub -I -n \\\${SLOTS} /usr/local/bin/mpirun \${SHARED}/mpi/hello_c"
   echo
;;
*)
   echo "   bsub -I -n \\\${SLOTS} /usr/local/bin/mpirun \${SHARED}/mpi/hello_c"
   echo
   bsub -I -n \\\${SLOTS} /usr/local/bin/mpirun \${SHARED}/mpi/hello_c
;;
esac
EOF2
   chmod 755 ~/HowTo_openMPI.sh
EOF1
   chmod 755 /tmp/openmpi_howto.sh
}

############################################################
####################### openMPI end ########################
############################################################

############################################################
#################### PlatformMPI start #####################
############################################################

write_platformmpi_master () {
   cat >> /tmp/platformmpi_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   echo "MPI is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Installing PlatformMPI" | tee -a \${LOG}
cd /tmp
echo "Downloading PlatformMPI tarball from box" | tee -a \${LOG}
echo "   lsf-pmpi-hpc-9.1.4-1.x86_64.rpm" | tee -a \${LOG}
curl -Lo lsf-pmpi-hpc-9.1.4-1.x86_64.rpm https://ibm.box.com/shared/static/s6ez87seb5noa77iwq7iohug2lx6ju7a.rpm >> \${LOG} 2>&1
cd /tmp
yum -y --nogpgcheck install lsf-pmpi-hpc-9.1.4-1.x86_64.rpm gcc >> \${LOG} 2>&1
export MPI_ROOT="/opt/ibm/platform_mpi"
echo "Compiling hello_world.c" | tee -a \${LOG}
mkdir -p \${SHARED}/platformmpi
chmod 755 \${SHARED}/platformmpi
\${MPI_ROOT}/bin/mpicc -o \${SHARED}/platformmpi/hello_world.out \${MPI_ROOT}/help/hello_world.c >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/platformmpi_master.sh
}

write_platformmpi_compute () {
   cat >> /tmp/platformmpi_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   echo "MPI is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Installing PlatformMPI" | tee -a \${LOG}
echo "Installing PlatformMPI" | tee -a \${LOG}
cd /tmp
echo "Downloading PlatformMPI tarball from box" | tee -a \${LOG}
echo "   lsf-pmpi-hpc-9.1.4-1.x86_64.rpm" | tee -a \${LOG}
curl -Lo lsf-pmpi-hpc-9.1.4-1.x86_64.rpm https://ibm.box.com/shared/static/s6ez87seb5noa77iwq7iohug2lx6ju7a.rpm >> \${LOG} 2>&1
cd /tmp
yum -y --nogpgcheck install lsf-pmpi-hpc-9.1.4-1.x86_64.rpm gcc >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/platformmpi_compute.sh
}

write_platformmpi_howto () {
   cat >> /tmp/platformmpi_howto.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"

SHARED=\$1

echo | tee -a \${LOG}
echo "Argument 1 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}
cat >> ~/HowTo_PlatformMPI.sh <<EOF2
#!/bin/sh

SLOTS=\\\`sudo -i -u lsfadmin bhosts | egrep ok | awk 'BEGIN{S=0}{S=S+\\\$4}END{print S}'\\\`

USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "Login as lsfadmin and execute:"
   echo "   bsub -I -n \\\${SLOTS} /opt/ibm/platform_mpi/bin/mpirun \${SHARED}/platformmpi/hello_world.out"
   echo
;;
*)
   echo "   bsub -I -n \\\${SLOTS} /opt/ibm/platform_mpi/bin/mpirun \${SHARED}/platformmpi/hello_world.out"
   echo
   bsub -I -n \\\${SLOTS} /opt/ibm/platform_mpi/bin/mpirun \${SHARED}/platformmpi/hello_world.out
;;
esac
EOF2
   chmod 755 ~/HowTo_PlatformMPI.sh
EOF1
   chmod 755 /tmp/platformmpi_howto.sh
}

############################################################
##################### PlatformMPI end ######################
############################################################

############################################################
####################### Podman start #######################
############################################################

write_podman_master () {
   cat >> /tmp/podman_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

case \${ID_LIKE} in
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install podman >> \${LOG} 2>&1
;;
*rhel*|*fedora*)
   yum -y --nogpgcheck install podman >> \${LOG} 2>&1
;;
esac
ln -s /usr/bin/podman /usr/bin/docker

echo "Modifying LSF configuration" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

cat >> \${LSF_TOP}/conf/lsf.conf <<EOF2
LSF_LINUX_CGROUP_ACCT=Y
#LSB_RESOURCE_ENFORCE="cpu memory"
EOF2

CLUSTERNAME=\`ls \${LSF_TOP}/conf/lsf.cluster.* | awk 'BEGIN{FS="."}{print \$NF}'\`
sed -i s/"()"/"(podman apptainer)"/g \${LSF_TOP}/conf/lsf.cluster.\${CLUSTERNAME}

STRING="   podman     Boolean ()       ()          (Podman-Docker container)"
sed -i s/"End Resource"/"\${STRING}\nEnd Resource"/g \${LSF_TOP}/conf/lsf.shared
cat >> \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.applications <<EOF2

Begin Application
NAME = podmanapp
RES_REQ = span[hosts=1]
CONTAINER = podman[image(centos) options(--rm)]
DESCRIPTION = Podman
EXEC_DRIVER = context[user(default)] \\
   starter[\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/docker-starter.py] \\
   controller[\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/docker-control.py]
End Application
EOF2

if test "\${REGION}" = "onprem"
then
   echo "Restarting LSF" | tee -a \${LOG}
   systemctl restart lsfd >> \${LOG} 2>&1
fi

case \${ID_LIKE} in
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install podman >> \${LOG} 2>&1
   ln -s /usr/bin/podman /usr/bin/docker
;;
esac

echo "Setting permissions for podman users" | tee -a \${LOG}

USERS="lsfadmin"

CNT=0
case \${ID_LIKE} in
*rhel*|*fedora*)
   rm -rf /etc/subuid /etc/subgid
;;
esac

for USER in \$USERS
do
   case \${ID_LIKE} in
   *rhel*|*fedora*)
      echo "\${USER}:1000\${CNT}:65536" >> /etc/subuid
      echo "\${USER}:1000\${CNT}:65536" >> /etc/subgid
   ;;
   esac
   loginctl enable-linger \${USER}
   CNT=\`expr \$CNT + 1\`
done

case \${ID_LIKE} in
*rhel*|*fedora*)
   setcap cap_setuid+eip /usr/bin/newuidmap >> \${LOG} 2>&1
   setcap cap_setgid+eip /usr/bin/newgidmap >> \${LOG} 2>&1
;;
esac
touch /etc/containers/nodocker
EOF1
   chmod 755 /tmp/podman_master.sh
}

write_podman_compute () {
   cat >> /tmp/podman_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

case \${ID_LIKE} in
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install podman >> \${LOG} 2>&1
;;
*rhel*|*fedora*)
   yum -y --nogpgcheck install podman >> \${LOG} 2>&1
;;
esac
ln -s /usr/bin/podman /usr/bin/docker

echo "Setting permissions for podman users" | tee -a \${LOG}

USERS="lsfadmin"

CNT=0
case \${ID_LIKE} in
*rhel*|*fedora*)
   rm -rf /etc/subuid /etc/subgid
;;
esac

for USER in \$USERS
do
   case \${ID_LIKE} in
   *rhel*|*fedora*)
      echo "\${USER}:1000\${CNT}:65536" >> /etc/subuid
      echo "\${USER}:1000\${CNT}:65536" >> /etc/subgid
   ;;
   esac
   loginctl enable-linger \${USER}
   CNT=\`expr \$CNT + 1\`
done

case \${ID_LIKE} in
*rhel*|*fedora*)
   setcap cap_setuid+eip /usr/bin/newuidmap >> \${LOG} 2>&1
   setcap cap_setgid+eip /usr/bin/newgidmap >> \${LOG} 2>&1
;;
esac
touch /etc/containers/nodocker

echo "Pulling image centos for lsfadmin" | tee -a \${LOG}
sudo -i -u lsfadmin podman pull quay.io/centos/centos >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/podman_compute.sh
}

write_podman_howto () {
   cat >> /tmp/podman_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Podman.sh <<EOF2
#!/bin/sh

echo "Submitting podman job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -app podmanapp -I hostname"
   echo
   sudo -i -u lsfadmin bsub -app podmanapp -I hostname
;;
*)
   echo "   bsub -app podmanapp -I hostname"
   echo
   bsub -app podmanapp -I hostname
;;
esac
EOF2
   chmod 755 ~/HowTo_Podman.sh
EOF1
   chmod 755 /tmp/podman_howto.sh
}

############################################################
######################## Podman end ########################
############################################################

############################################################
################## ProcessManager start ####################
############################################################

write_process_manager_master () {
   cat >> /tmp/process_manager_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   echo "Process Manager is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Install chkconfig" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install chkconfig >> \${LOG} 2>&1
;;
esac
cd /tmp
echo "Downloading ProcessManager tarballs from box" | tee -a \${LOG}
echo "   ppm10.2_pinstall.tar.Z" | tee -a \${LOG}
curl -Lo ppm10.2_pinstall.tar.Z https://ibm.box.com/shared/static/7amwhj8blhfl7onin51knje6nnf5ium6.z >> \${LOG} 2>&1
echo "   ppm10.2_fm_lnx26-x64.tar.Z" | tee -a \${LOG}
curl -Lo ppm10.2_fm_lnx26-x64.tar.Z https://ibm.box.com/shared/static/x1ly0d9l1x5p6egxmk8c55kczg8t6ipw.z >> \${LOG} 2>&1
echo "   ppm10.2_ed_lnx26-x64.tar.Z" | tee -a \${LOG}
curl -Lo ppm10.2_ed_lnx26-x64.tar.Z https://ibm.box.com/shared/static/75lclefpc1k0zoovrh1bmbu8lz4i3izi.z >> \${LOG} 2>&1
echo "   ppm10.2_svr_lnx26-x64.tar.Z" | tee -a \${LOG}
curl -Lo ppm10.2_svr_lnx26-x64.tar.Z https://ibm.box.com/shared/static/fyfupubc86kn01qsqkm143y0bd5pkje9.z >> \${LOG} 2>&1

echo "Install ProcessManager" | tee -a \${LOG}
tar xzf ppm10.2_pinstall.tar.Z
cd ppm10.2_pinstall
cat >> install.config <<EOF2
JS_TOP=/usr/local/pm
JS_HOST=${HOSTNAME}
JS_TARDIR=/tmp
JS_ADMINS="lsfadmin"
LSF_ENVDIR=\${LSF_TOP}/conf
EOF2
sed -i s/"version = \"4\""/"version = \"5\""/g instlib/binary_type.sh
./jsinstall -s -y -f install.config
ln -s /usr/local/pm/conf/profile.js /etc/profile.d/profile.js.sh
. /usr/local/pm/conf/profile.js
/usr/local/pm/10.2/install/bootsetup
service jstartup start

echo "Creating desktop links"
for APP in floweditor flowmanager
do
   echo "xhost + ; sudo -u lsfadmin /tmp/exec2_\${APP}.sh" >> /tmp/exec1_\${APP}.sh
   chmod 755 /tmp/exec1_\${APP}.sh
   echo ". /usr/local/pm/conf/profile.js ; \${APP}" >> /tmp/exec2_\${APP}.sh
   chmod 755 /tmp/exec2_\${APP}.sh
   DESKTOP_LINK="/root/Desktop/\${APP}.desktop"
   cat >> \${DESKTOP_LINK} <<EOF2
[Desktop Entry]
Type=Application
Terminal=false
Exec=/tmp/exec1_\${APP}.sh
Name=\${APP}
Icon=application-x-executable
EOF2
   gio set \${DESKTOP_LINK} "metadata::trusted" true
   chmod 755 "\${DESKTOP_LINK}"
done
EOF1
   chmod 755 /tmp/process_manager_master.sh
}

write_process_manager_howto () {
   cat >> /tmp/process_manager_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_ProcessManager.sh <<EOF2
#!/bin/sh

echo
echo "Execute on the commandline:"
echo "   /tmp/exec2_flowmanager.sh"
echo "   /tmp/exec2_floweditor.sh"
echo
EOF2
   chmod 755 ~/HowTo_ProcessManager.sh
EOF1
   chmod 755 /tmp/process_manager_howto.sh
}

############################################################
################### ProcessManager end #####################
############################################################

############################################################
######################### R start ##########################
############################################################

write_r () {
   cat >> /tmp/r.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing R" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   crb enable 1>/dev/null 2>/dev/null
   yum -y --nogpgcheck install R >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install r-base r-base-dev >> \${LOG} 2>&1
   cd /tmp
;;
esac
EOF1
   chmod 755 /tmp/r.sh
}

write_r_howto () {
   cat >> /tmp/r_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_R.sh <<EOF2
#!/bin/sh

echo "Submitting R job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -Is R"
   echo
   sudo -i -u lsfadmin bsub -Is R
;;
*)
   echo "   bsub -Is R"
   echo
   bsub -Is R
;;
esac
EOF2
   chmod 755 ~/HowTo_R.sh
EOF1
   chmod 755 /tmp/r_howto.sh
}

############################################################
########################## R end ###########################
############################################################

############################################################
####################### rDock start ########################
############################################################

write_rdock () {
   cat >> /tmp/rdock.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing rDock" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install git 1>/dev/null 2>/dev/null
   yum -y --nogpgcheck install make gcc g++ popt-devel >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install git 1>/dev/null 2>/dev/null
   apt -y -qq install make gcc g++ libpopt0 libpopt-dev 1>/dev/null 2>/dev/null
;;
esac
cd /tmp
git clone https://github.com/CBDD/rDock
cd rDock
make
make test
make install
ln -s /usr/lib/libRbt.so /usr/lib64/libRbt.so
EOF1
   chmod 755 /tmp/rdock.sh
}

write_rdock_howto () {
   cat >> /tmp/rdock_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_rDock.sh <<EOF2
#!/bin/sh

echo "Submitting rDock job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -Is rbdock  | head -10"
   echo
   sudo -i -u lsfadmin bsub -Is rbdock  | head -10
;;
*)
   echo "   bsub -Is rbdock  | head -10"
   echo
   bsub -Is rbdock  | head -10
;;
esac
EOF2
   chmod 755 ~/HowTo_rDock.sh
EOF1
   chmod 755 /tmp/rdock_howto.sh
}

############################################################
######################## rDock end #########################
############################################################

############################################################
######################## RDP start #########################
############################################################

write_rdp_master () {
   cat >> /tmp/rdp_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

ROOTPWD=\$1

echo | tee -a \${LOG}
echo "Argument 1 ROOTPWD: \${ROOTPWD}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Getting several packages" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install ImageMagick >> \${LOG} 2>&1
   yum -y --nogpgcheck groupinstall "Server with GUI" >> \${LOG} 2>&1
;;
*debian*)
   apt-get -yq update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install imagemagick >> \${LOG} 2>&1
;;
esac

ALL_USERS="root lsfadmin"
for USER in \${ALL_USERS}
do
   echo "Changing password for \${USER}" | tee -a \${LOG}
   case \${ID_LIKE} in
   *rhel*|*fedora*)
      echo "\${ROOTPWD}" | passwd --stdin \${USER} >> \${LOG} 2>&1
   ;;
   *debian*)
      sed -i s/"pam_pwquality.so"/"pam_pwquality.so dictcheck=0"/g /etc/pam.d/common-password
      echo "\${USER}:\${ROOTPWD}" | chpasswd >> \${LOG} 2>&1
   ;;
   esac
done

echo "Creating setup_user_desktop" | tee -a \${LOG}
cat >> /usr/bin/setup_user_desktop.sh <<EOF2
#!/bin/sh

. /etc/os-release
. /var/environment.sh

########################################
echo "yes" >> ~/.config/gnome-initial-setup-done
########################################
echo "User 01 - Modify gnome-shell-extension-desktop-icons"
gsettings set org.gnome.shell enabled-extensions "['apps-menu@gnome-shell-extensions.gcampax.github.com', 'desktop-icons@gnome-shell-extensions.gcampax.github.com', 'horizontal-workspaces@gnome-shell-extensions.gcampax.github.com', 'launch-new-instance@gnome-shell-extensions.gcampax.github.com', 'places-menu@gnome-shell-extensions.gcampax.github.com', 'top-icons@gnome-shell-extensions.gcampax.github.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'window-list@gnome-shell-extensions.gcampax.github.com']"
########################################
echo "User 02 - Modify terminal colors"
ID=\\\`gsettings list-recursively | fgrep "org.gnome.Terminal.ProfilesList default" | awk '{print \\\$3}' | sed s/"'"//g\\\`
dconf write /org/gnome/terminal/legacy/profiles:/:\\\${ID}/use-theme-colors "false"
dconf write /org/gnome/terminal/legacy/profiles:/:\\\${ID}/background-color "'rgb(255,255,255)'"
dconf write /org/gnome/terminal/legacy/profiles:/:\\\${ID}/foreground-color "'rgb(0,0,0)'"
########################################
echo "User 03 - Set blankscreen timeout"
gsettings set org.gnome.desktop.session idle-delay 0
########################################
echo "User 04 - Extend languages/kbd"
dconf write /org/gnome/desktop/input-sources/sources "[('xkb', 'de'), ('xkb', 'fr'), ('xkb', 'gb')]"
########################################
echo "User 08 - Modifying ~/.bashrc"
echo "Modifying \${HOME}/.bashrc"
cat >> ~/.bashrc <<EOF3
cd
EOF3
########################################
echo "User 09 - Create desktop links"

ICON_TERMINAL="utilities-terminal"
if test -f /usr/share/icons/Yaru/48x48/apps/gnome-terminal.png
then
   ICON_TERMINAL="/usr/share/icons/Yaru/48x48/apps/gnome-terminal.png"
fi
if test -f /usr/share/icons/Yaru/48x48@2x/apps/terminal-app.png
then
   ICON_TERMINAL="/usr/share/icons/Yaru/48x48@2x/apps/terminal-app.png"
fi
ICON_MONITOR="/usr/share/icons/HighContrast/scalable/apps/utilities-system-monitor.svg"
if test -f /usr/share/icons/Yaru/48x48/apps/gnome-system-monitor.png
then
   ICON_MONITOR="/usr/share/icons/Yaru/48x48/apps/gnome-system-monitor.png"
fi
if test -f /usr/share/icons/HighContrast/scalable/apps/utilities-system-monitor.svg
then
   ICON_MONITOR="/usr/share/icons/HighContrast/scalable/apps/utilities-system-monitor.svg"
fi

DESKTOP_LINK="\\\${HOME}/Desktop/Monitor.desktop"
cat << EOF3 >> \\\${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=gnome-system-monitor -r
Name=Monitor
Icon=\\\${ICON_MONITOR}
EOF3
gio set \\\${DESKTOP_LINK} "metadata::trusted" true
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
chmod 755 "\\\${DESKTOP_LINK}"
DESKTOP_LINK="\\\${HOME}/Desktop/Terminal.desktop"
cat << EOF3 >> \\\${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=gnome-terminal
Name=Terminal
Icon=\\\${ICON_TERMINAL}
EOF3
gio set \\\${DESKTOP_LINK} "metadata::trusted" true
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
chmod 755 "\\\${DESKTOP_LINK}"

#rm -rf ~/.config/autostart/start_node.desktop 1>/dev/null 2>/dev/null
EOF2
chmod 755  /usr/bin/setup_user_desktop.sh

echo "Installing xrdp" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install tigervnc-server xrdp >> \${LOG} 2>&1
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install ubuntu-desktop desktopfolder >> \${LOG} 2>&1
   apt -y -qq install tigervnc-standalone-server tigervnc-xorg-extension tigervnc-viewer xrdp >> \${LOG} 2>&1
;;
esac

ALL_USERS="root lsfadmin"
for USER in \${ALL_USERS}
do
   if test "\${USER}" = "root"
   then
      HOME="/root"
   else
      HOME="/home/\${USER}"
   fi

   mkdir -p \${HOME}/.config/autostart
   cat >> \${HOME}/.config/autostart/start_node.desktop <<EOF2
[Desktop Entry]
Exec=gnome-terminal -e "bash -c \\\"setup_user_desktop.sh\\\""
Type=Application
EOF2
   echo "yes" >> \${HOME}/.config/gnome-initial-setup-done
   chown -R \${USER}:\${USER} \${HOME}/.config
done

case \${ID_LIKE} in
*rhel*|*fedora*)
   sed -i s/"AutomaticLogin"/"#AutomaticLogin"/g /etc/gdm/custom.conf
;;
*debian*)
   sed -i s/"AutomaticLogin"/"#AutomaticLogin"/g /etc/gdm3/custom.conf
;;
esac

systemctl enable xrdp >> \${LOG} 2>&1
systemctl start xrdp >> \${LOG} 2>&1

echo "Creating new backgrounds" | tee -a \${LOG}
if test -d /usr/share/backgrounds
then
   cd /usr/share/backgrounds
   rm -rf *ORIG
   for IMG in \`ls *.jpg *.png 2>/dev/null\`
   do
      SIZE=\`identify \$IMG | awk '{print \$3}'\`
      WIDTH=\`echo \${SIZE} | awk 'BEGIN{FS="x"}{print \$1}'\`
      POINTSIZE=\`expr \${WIDTH} / 20\`
      SHORT=\`echo \${IMG} | sed -e s/".jpg"//g -e s/".png"//g\`
      SUFFIX=\`echo \${IMG} | awk 'BEGIN{FS="."}{print \$NF}'\`
      rm -rf \${IMG}
      if test -f /var/custom_image.jpg
      then
         convert /var/custom_image.jpg -size \${SIZE} -pointsize \${POINTSIZE} -gravity center -annotate 0 "\${HOSTNAME}" \$IMG >> \${LOG} 2>&1
      else
         convert -size \${SIZE} xc:white -pointsize \${POINTSIZE} -gravity center label:"\${HOSTNAME}" \$IMG >> \${LOG} 2>&1
         rm -rf \${SHORT}-0.\${SUFFIX}
         mv \${SHORT}-1.\${SUFFIX} \${SHORT}.\${SUFFIX} >> \${LOG} 2>&1
      fi
   done
fi

echo "Annotating" | tee -a \${LOG}
cat >> /usr/bin/annotate.sh <<EOF2
#!/bin/sh

sleep 2

. /etc/os-release
. /var/environment.sh

HOSTNAME=\\\`hostname -s\\\`
ADD_HN="\\\${HOSTNAME}     \n"
FQDN=\\\`hostname -f\\\`
if test "\\\${HOSTNAME}" != "\\\${FQDN}"
then
   ADD_FQDN="FQDN: \\\${FQDN}     \n"
fi

REL=\\\`echo \\\${NAME} \\\${VERSION_ID} | awk '{printf("OS: %s\n",\\\$0)}'\\\`
ADD_REL="\\\${REL}     \n"

FIRST_IF=\\\`ifconfig 2>/dev/null | egrep '(ens|enp|eth)' | egrep -v ether | awk 'BEGIN{FS=":"}{print \\\$1}' | head -1\\\`
FIRST_IP=\\\`ifconfig \\\${FIRST_IF} 2>/dev/null | fgrep "inet " | awk '{print \\\$2}'\\\`
if test "\\\${FIRST_IP}" = ""
then
   FIRST_IP=\\\`ifconfig br-ex 2>/dev/null | fgrep "inet " | awk '{print \\\$2}'\\\`
fi
SECOND_IF=\\\`ifconfig 2>/dev/null | egrep '(ens|enp|eth)' | egrep -v ether | awk 'BEGIN{FS=":"}{print \\\$1}' | tail -1\\\`
SECOND_IP=\\\`ifconfig \\\${SECOND_IF} 2>/dev/null | fgrep "inet " | awk '{print \\\$2}'\\\`

if test "\\\${SECOND_IP}" = "" -o "\\\${SECOND_IP}" = "\\\${FIRST_IP}"
then
   ADD_IP="IP \\\${FIRST_IF}: \\\${FIRST_IP}     \n"
else
   ADD_IP="IP \\\${FIRST_IF}: \\\${FIRST_IP}     \nIP \\\${SECOND_IF}: \\\${SECOND_IP}     \n"
fi

ADD_SF=""
for CAND in /mnt/hgfs /media
do
   RES=\\\`ls \\\${CAND} 2>/dev/null\\\`
   for SUB in \\\${RES}
   do
      CONT=\\\`ls \\\${CAND}/\\\${SUB}/* 2>/dev/null\\\`
      if test "\\\${CONT}" != ""
      then
         ADD_SF="\\\${ADD_SF}Shared Folder: \\\${CAND}/\\\${SUB}     \n"
      fi
   done
done

ADD_CORES=\\\`lscpu | egrep "^CPU\(s\):" | awk '{printf("Cores: %s     \\\\\\\\\n",\\\$2)}'\\\`
ADD_MEM=\\\`cat /proc/meminfo | egrep "MemTotal:" | awk '{printf("Mem: %.1f GiB     \\\\\\\\\n",\\\$2/1048576)}'\\\`
ADD_SWAP=\\\`cat /proc/meminfo | egrep "SwapTotal:" | awk '{printf("Swap: %.1f GiB     \\\\\\\\\n",\\\$2/1048576)}'\\\`

case \\\$ID_LIKE in
*rhel*|*fedora*)
   PS=30
   XOFFSET=0
;;
*debian*)
   PS=30
   XOFFSET=100
;;
esac
for BACKGROUND in \\\`ls /usr/share/backgrounds/*.jpg /usr/share/backgrounds/*.png 2>/dev/null | egrep -v _ORIG\\\`
do
   if test ! -f \\\${BACKGROUND}_ORIG
   then
      cp \\\${BACKGROUND} \\\${BACKGROUND}_ORIG
   fi
   convert -pointsize \\\${PS} -annotate +\\\${XOFFSET}+0 "\n\n\n\n\n\n\n\nHostname: \\\${ADD_HN}\\\${ADD_FQDN}\\\${ADD_REL}\\\${ADD_CORES}\\\${ADD_MEM}\\\${ADD_SWAP}\\\${ADD_IP}\\\${ADD_SF}" -gravity northeast \\\${BACKGROUND}_ORIG \\\${BACKGROUND}
done
EOF2
chmod 755 /usr/bin/annotate.sh
/usr/bin/annotate.sh
EOF1
   chmod 755 /tmp/rdp_master.sh
}

############################################################
######################### RDP end ##########################
############################################################

############################################################
################# Resource connector start #################
############################################################

write_resource_connector_master () {
   cat >> /tmp/resource_connector_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
APIKEY=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 APIKEY: \${APIKEY}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Installing ibm_vpc and ibm_cloud_networking_services" | tee -a \${LOG}
pip install ibm_vpc ibm_cloud_networking_services >> \${LOG} 2>&1

echo "Modifying LSF configuration" | tee -a \${LOG}
STRING="   icgen2host   Boolean ()       ()          (IBM Host)"
sed -i s/"End Resource"/"\${STRING}\nEnd Resource"/g \${LSF_TOP}/conf/lsf.shared

cat >> \${LSF_TOP}/conf/lsf.conf <<EOF2
LSB_RC_EXTERNAL_HOST_FLAG=icgen2host
LSB_RC_EXTERNAL_HOST_IDLE_TIME=30
EOF2

CLUSTERNAME=\`ls \${LSF_TOP}/conf/lsf.cluster.* | awk 'BEGIN{FS="."}{print \$NF}'\`
sed -i s/"#schmod_demand"/"schmod_demand"/g \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.modules

cat >> \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.queues <<EOF2

Begin Queue
QUEUE_NAME       = normal
RES_REQ          = select[type==any]
PRIORITY         = 40
RES_REQ          = span[hosts=1]
INTERACTIVE      = YES
RC_HOSTS         = icgen2host
RC_DEMAND_POLICY = THRESHOLD[[1,1]]
End Queue

Begin Queue
QUEUE_NAME       = rcv
RES_REQ          = select[type==any]
PRIORITY         = 40
INTERACTIVE      = YES
RC_HOSTS         = icgen2host
RC_DEMAND_POLICY = THRESHOLD[[1,1]]
End Queue
EOF2

sed -i s/"End Parameters"/"RUNTIME_LOG_INTERVAL=10\nEnd Parameters"/g \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.params
sed -i s/"normal interactive"/"normal"/g \${LSF_TOP}/conf/lsbatch/\${CLUSTERNAME}/configdir/lsb.params

mkdir -p \${LSF_TOP}/conf/resource_connector/ibmcloudgen2

cp -r \${LSF_TOP}/10.1/resource_connector/ibmcloudgen2/conf \${LSF_TOP}/conf/resource_connector/ibmcloudgen2

cat > \${LSF_TOP}/conf/resource_connector/hostProviders.json <<EOF2
{
    "providers":[
        {
            "name": "ibmcloudgen2",
            "type": "ibmcloudgen2Prov",
            "path": "resource_connector/ibmcloudgen2/provider.json"
        }
    ]
}
EOF2

cat > \${LSF_TOP}/conf/resource_connector/ibmcloudgen2/provider.json <<EOF2
{
    "host_type": "ibmcloudgen2comp",
    "interfaces":
    [{
        "name": "getAvailableTemplates",
        "action": "resource_connector/ibmcloudgen2/scripts/getAvailableTemplates.sh"
    },
    {
        "name": "getReturnRequests",
        "action": "resource_connector/ibmcloudgen2/scripts/getReturnRequests.sh"
    },
    {
        "name": "requestMachines",
        "action": "resource_connector/ibmcloudgen2/scripts/requestMachines.sh"
    },
    {
        "name": "requestReturnMachines",
        "action": "resource_connector/ibmcloudgen2/scripts/requestReturnMachines.sh"
    },
    {
        "name": "getRequestStatus",
        "action": "resource_connector/ibmcloudgen2/scripts/getRequestStatus.sh"
    }]
}
EOF2

cat > \${LSF_TOP}/conf/resource_connector/ibmcloudgen2/conf/credentials <<EOF2
# BEGIN ANSIBLE MANAGED BLOCK
VPC_URL=http://vpc.cloud.ibm.com/v1
VPC_AUTH_TYPE=iam
VPC_APIKEY=\${APIKEY}
RESOURCE_RECORDS_URL=https://api.dns-svcs.cloud.ibm.com/v1
RESOURCE_RECORDS_AUTH_TYPE=iam
RESOURCE_RECORDS_APIKEY=\${APIKEY}
# END ANSIBLE MANAGED BLOCK
EOF2

cat > \${LSF_TOP}/conf/resource_connector/ibmcloudgen2/conf/ibmcloudgen2_config.json <<EOF2
{
  "IBMCLOUDGEN2_KEY_FILE": "/usr/share/lsf/conf/resource_connector/ibmcloudgen2/conf/credentials",
  "IBMCLOUDGEN2_SSH_FILE": "/usr/share/lsf/conf/resource_connector/ibmcloudgen2/conf/id_rsa",
  "IBMCLOUDGEN2_PROVISION_FILE": "/usr/share/lsf/10.1/resource_connector/ibmcloudgen2/scripts/user_data.sh",
  "IBMCLOUDGEN2_MACHINE_PREFIX": "lsf-rc",
  "LogLevel": "INFO"
}
EOF2
if test "\${REGION}" = "onprem"
then
   echo "Restarting LSF" | tee -a \${LOG}
   RET=\`systemctl status lsfd\`
   if test "\${RET}" = ""
   then
      . \${LSF_TOP}/conf/profile.lsf
      lsf_daemons restart
   else
      systemctl restart lsfd
   fi
fi
EOF1
   chmod 755 /tmp/resource_connector_master.sh
}

write_resource_connector_howto () {
   cat >> /tmp/resource_connector_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_ResourceConnector.sh <<EOF2
#!/bin/sh

echo "Executing:"
echo "   tail -f \${LSF_TOP}/log/*-provider.log.*"
tail -f \${LSF_TOP}/log/*-provider.log.*
EOF2
   chmod 755 ~/HowTo_ResourceConnector.sh
EOF1
   chmod 755 /tmp/resource_connector_howto.sh
}

############################################################
################## Resource connector end ##################
############################################################

############################################################
######################## RTM start #########################
############################################################

write_rtm_master () {
   cat >> /tmp/rtm_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing PHP 7.4" | tee -a \${LOG}
# Need php 7.4 to work, 8.x will not...
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm >> \${LOG} 2>&1
   yum -y module install php:remi-7.4 >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   add-apt-repository -y ppa:ondrej/php >> \${LOG} 2>&1
   apt -y install php7.4 >> \${LOG} 2>&1
;;
esac

echo "Installing several packages" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y install git bash chkconfig chrony coreutils gd httpd initscripts libnsl mariadb mariadb-connector-odbc mariadb-server mod_ssl perl php php-common php-gd php-json php-ldap php-mbstring php-mysqlnd php-process php-xml python3-pexpect python3-pyOpenSSL rrdtool rsyslog rsyslog-mysql shadow-utils unixODBC httpd php-gmp php-intl php-snmp net-snmp-utils >> \${LOG} 2>&1
;;
*debian*)
   apt -y install snmp php7.4-snmp rrdtool librrds-perl unzip curl git gnupg2 apache2 mariadb-server php7.4-mysql libapache2-mod-php7.4 php7.4-xml php7.4-ldap php7.4-mbstring php7.4-gd php7.4-gmp libodbc2 libodbcinst2 snmp-mibs-downloader >> \${LOG} 2>&1
;;
esac

echo "Cloning ibm-spectrum-lsf-rtm-server" | tee -a \${LOG}

git clone https://github.com/IBM/ibm-spectrum-lsf-rtm-server >> \${LOG} 2>&1
mv ibm-spectrum-lsf-rtm-server/cacti /var/www/html

echo "Modifying configuration" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "   /etc/php.ini"
   sed -i s/";date.timezone ="/"date.timezone = Europe\/Berlin"/g /etc/php.ini
   sed -i s/"memory_limit = 128M"/"memory_limit = 400M"/g /etc/php.ini
   sed -i s/"max_execution_time = 30"/"max_execution_time = 60"/g /etc/php.ini
;;
*debian*)
   for PHP_INI in /etc/php/7.4/cli/php.ini /etc/php/7.4/apache2/php.ini
   do
      echo "   \${PHP_INI}"
      sed -i s/";date.timezone ="/"date.timezone = Europe\/Berlin"/g \${PHP_INI}
      sed -i s/"memory_limit = 128M"/"memory_limit = 400M"/g \${PHP_INI}
      sed -i s/"max_execution_time = 30"/"max_execution_time = 60"/g \${PHP_INI}
   done
;;
esac

case \${ID_LIKE} in
*rhel*|*fedora*)
   SERVER_CNF="/etc/my.cnf.d/server.cnf" ;;
*debian*)
   SERVER_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf" ;;
esac

echo "   \${SERVER_CNF}"  | tee -a \${LOG}
cat > \${SERVER_CNF} <<EOF2
[mysqld]

character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci
max_connections = 100
max_heap_table_size = 32M
max_allowed_packet = 16M
tmp_table_size = 32M
join_buffer_size = 64M
sort_buffer_size = 16M
sql_mode=ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
innodb_buffer_pool_size = 431M
innodb_buffer_pool_instances = 16M
innodb_log_file_size = 16M
innodb_log_buffer_size = 16M
innodb_sort_buffer_size = 16M
innodb_doublewrite = ON
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = ON
innodb_file_format = Barracuda
innodb_large_prefix = 1
innodb_flush_log_at_timeout = 3
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_io_capacity = 5000
innodb_io_capacity_max = 10000
innodb_flush_method = O_DIRECT
EOF2

echo "   /var/www/html/cacti/include/config.php"  | tee -a \${LOG}
cat > /var/www/html/cacti/include/config.php <<EOF2
<?php

\\\$database_type     = 'mysql';
\\\$database_default  = 'cacti';
\\\$database_hostname = 'localhost';
\\\$database_username = 'cacti';
\\\$database_password = 'cacti';
\\\$database_port     = '3306';
\\\$database_retries  = 5;
\\\$database_ssl      = false;
\\\$database_ssl_key  = '';
\\\$database_ssl_cert = '';
\\\$database_ssl_ca   = '';
\\\$database_persist  = false;
\\\$poller_id = 1;
\\\$url_path = '/cacti/';
\\\$cacti_session_name = 'Cacti';
//\\\$cacti_cookie_domain = 'cacti.net';
\\\$cacti_db_session = false;
\\\$disable_log_rotation = false;
//\\\$scripts_path = '/var/www/html/cacti/scripts';
//\\\$resource_path = '/var/www/html/cacti/resource/';
//\\\$input_whitelist = '/usr/local/etc/cacti/input_whitelist.json';
//\\\$php_path = '/bin/php';
//\\\$php_snmp_support = false;
//\\\$path_csrf_secret = '/usr/share/cacti/resource/csrf-secret.php';
\\\$proxy_headers = null;
\\\$i18n_handler = null;
\\\$i18n_force_language = null;
\\\$i18n_log = null;
\\\$i18n_text_log = null;
EOF2

echo "Starting services" | tee -a \${LOG}
mkdir -p /var/www/html/cacti/gridcache
chmod 777 /var/www/html/cacti/gridcache
mkdir -p /opt/IBM
ln -s /var/www/html/cacti /opt/IBM/cacti
cp -p /var/www/html/cacti/service/cactid.service /etc/systemd/system
mkdir -p /etc/sysconfig
touch /etc/sysconfig/cactid
echo "   cactid" | tee -a \${LOG}
systemctl enable cactid >> \${LOG} 2>&1
systemctl start cactid >> \${LOG} 2>&1
echo "   httpd" | tee -a \${LOG}

# Change to 8181, as it conflics with Guacamole
sed -i s/"Listen 80"/"Listen 8181"/g /etc/httpd/conf/httpd.conf

systemctl enable httpd >> \${LOG} 2>&1
systemctl start httpd >> \${LOG} 2>&1
echo "   mariadb" | tee -a \${LOG}
systemctl enable mariadb >> \${LOG} 2>&1
systemctl start mariadb >> \${LOG} 2>&1

echo "Setting up database" | tee -a \${LOG}
case \${ID_LIKE} in
*debian*)
   GID=\`addgroup apache 2>/dev/null | egrep GID | awk '{print \$5}' | sed s/")"//g\`
   adduser apache --gid \${GID} --gecos "apache" --disabled-password >> \${LOG} 2>&1
;;
esac
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql
cat > input.txt <<EOF2
create database if not exists cacti;
use cacti;
source /var/www/html/cacti/cacti.sql;
CREATE USER 'cacti'@'localhost' IDENTIFIED BY 'cacti';
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'localhost';
GRANT SELECT ON mysql.time_zone_name TO 'cacti'@'localhost';
FLUSH PRIVILEGES;
ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
EOF2
cat input.txt | mariadb -u root
mysql -ucacti -pcacti cacti < /var/www/html/cacti/rtm.sql

chown -R apache.apache /var/www/html

echo "Installing RTM patch rtm10.2.0-build601132-centos8-x64.tar.gz" | tee -a \${LOG}

cd /tmp
echo "Downloading RTM poller tarball from box" | tee -a \${LOG}
echo "   rtm10.2.0-build601132-centos8-x64.tar.gz" | tee -a \${LOG}
curl -Lo rtm10.2.0-build601132-centos8-x64.tar.gz https://ibm.box.com/shared/static/s76z19j1tkvm07u24bkniy54rnd5kjoz.gz >> \${LOG} 2>&1
case \${ID_LIKE} in
*rhel*|*fedora*)
   tar xzf rtm10.2.0-build601132-centos8-x64.tar.gz >> \${LOG} 2>&1
   yum -y install ./x86_64/rtm-poller-10.2.0-13.601132.x86_64.rpm >> \${LOG} 2>&1
;;
*debian*)
   echo "   Install alien" | tee -a \${LOG}
   apt -y install alien >> \${LOG} 2>&1
   echo "   Convert rtm-poller-10.2.0-13.601132.x86_64.rpm"
   alien --scripts rtm-poller-10.2.0-13.601132.x86_64.rpm >> \${LOG} 2>&1
   echo "   Install rtm-poller_10.2.0-14.601132_amd64.deb"
   apt -y install ./rtm-poller_10.2.0-14.601132_amd64.deb >> \${LOG} 2>&1
   echo "Downloading mariadb-connector-odbc from box" | tee -a \${LOG}
   echo "   mariadb-connector-odbc-3.1.20-ubuntu-focal-amd64.deb" | tee -a \${LOG}
   curl -Lo mariadb-connector-odbc-3.1.20-ubuntu-focal-amd64.deb https://ibm.box.com/shared/static/tz4k3q0nadmz7j8ixvoilejr3euwzs3h.deb >> \${LOG} 2>&1
   apt -y install mariadb-connector-odbc-3.1.20-ubuntu-focal-amd64.deb >> \${LOG} 2>&1
   ln -s /usr/./lib/x86_64-linux-gnu/libmaodbc.so /usr/lib64/libmaodbc.so
;;
esac

echo "Changing configuration" | tee -a \${LOG}
cat > /opt/IBM/rtm/etc/lsfpollerd.conf <<EOF2
DB_Host         localhost
DB_Database     cacti
DB_User         cacti
DB_Pass         cacti
DB_Port         3306
DB_Pollerid     1
Log_File        /opt/IBM/cacti/log/cacti.log
Daemon_User     lsfadmin
EOF2

cat > /opt/IBM/rtm/lsf10.1.0.13/bin/grid.conf <<EOF2
DB_Host         localhost
DB_Database     cacti
DB_User         cacti
DB_Pass         cacti
DB_Port         3306
Log_File        /opt/IBM/cacti/log/cacti.log
Daemon_User     apache
EOF2

cat > /etc/odbc.ini <<EOF2
[cacti]
Description = Data Source for IBM Spectrum LSF RTM.
Driver      = MySQL RTM
EOF2

cat > /etc/odbcinst.ini <<EOF2
[MySQL RTM]
Description     = Mysql ODBC Driver for IBM Spectrum LSF RTM.
Driver64        = /usr/lib64/libmaodbc.so
UsageCount      = 1
CPTimeout       =
CPReuse         =
EOF2

cat > /etc/init.d/lsfpollerd <<EOF2
#!/bin/bash
# \\\$Id\\\$
#

# For RedHat and cousins:
# chkconfig: 2345 85 15
# description: LSF Poller Daemon
# processname: lsfpollerd
#
# source function library

# For SuSE Linux:
### BEGIN INIT INFO                         
# Provides:           lsfpollerd                
# Required-Start:     mariadb
# Required-Stop:                            
# Default-Start:      3 5
# Default-Stop:       0 1 2 6
# Short-Description:  LSF Poller for RTM
# Description:        Start the LSF Poller daemon to provide LSF information
# 					  for IBM Spectrum LSF RTM.
### END INIT INFO                           

RTM_TOP=/opt/IBM
PROG_BIN="lsfpollerd"
PROG_PATH="\\\$RTM_TOP/rtm/bin/"
OPTIONS="-c \\\$RTM_TOP/rtm/etc/lsfpollerd.conf"
export LD_LIBRARY_PATH=\\\$prog_path:\\\$LD_LIBRARY_PATH
START_CMD="\\\$PROG_PATH\\\$PROG_BIN \\\$OPTIONS"
SYSTEMCTL_SKIP_REDIRECT=Y
HTTPD_USER=\\\`grep Daemon_User \\\$RTM_TOP/rtm/etc/lsfpollerd.conf  | awk '{print \\\$NF}'\\\`
HTTPD_HOME=\\\`getent passwd \\\$HTTPD_USER | cut -f6 -d":"\\\`
export HOME=\\\$HTTPD_HOME

if [ -f /etc/SuSE-release ] || \\\`grep SUSE -q /etc/os-release\\\`; then
	test -x \\\$PROG_PATH\\\$PROG_BIN || exit 5

	# Source LSB init functions, if they exist
	[ -f /etc/rc.status ] && . /etc/rc.status

	# Reset status of this service
	rc_reset

	case "\\\$1" in
	start) 
		echo -n "Starting LSF Poller Daemon "
		/sbin/startproc \\\$START_CMD
		rc_status -v
		;;
	stop) 
		echo -n "Shutting down LSF Poller Daemon "
		## Stop the grid collector processes first
		for lsfdir in \\\`find \\\$RTM_TOP/rtm -type d -name "lsf*" -prune\\\`; do
			for gridbin in \\\`find \\\$lsfdir/bin/ -type f -name "grid*" | grep -v grid.conf\\\`; do
				pid=\\\`pidof \\\$gridbin\\\`
				if [ "\\\$pid" != "" ]; then
					/bin/kill \\\$pid
				fi
			done
		done

		## Stop daemon with killproc(8) and if this fails
		## killproc sets the return value according to LSB.
		/sbin/killproc -TERM \\\$PROG_BIN

		# Remember status and be verbose
		rc_status -v
		;;
	try-restart|condrestart)
		if test "\\\$1" = "condrestart"; then
			echo "\\\${attn} Use try-restart \\\${done}(LSB)\\\${attn} rather than condrestart \\\${warn}(RH)\\\${norm}"
		fi
		\\\$0 status
		if test \\\$? = 0; then
			\\\$0 restart
		else
			rc_reset
		fi
		rc_status
		;;
	restart)
		\\\$0 stop
		\\\$0 start
		rc_status
		;;
	force-reload)
		echo -n "Reload service LSF Poller Daemon "
		\\\$0 try-restart
		rc_status
		;;
	reload)
		echo -n "Reload service LSF Poller Daemon "
		rc_failed 3
		rc_status -v
		;;
	status)
		echo -n "Checking for service LSF Poller Daemon "
		/sbin/checkproc \\\$PROG_BIN
		rc_status -v
		;;
	probe)
		test \\\$RTM_TOP/rtm/etc/lsfpollerd.conf -nt /var/run/lsfpollerd.pid && echo reload
		;;
	*)
		echo "Usage: \\\$0 {start|stop|status|try-restart|restart|force-reload|reload|probe}"
		exit 1
		;;
	esac

	rc_exit
elif [ -f /etc/redhat-release ] ; then
	# Source function library
	[ -f /etc/rc.d/init.d/functions ] && . /etc/rc.d/init.d/functions

	RETVAL=0
	
	case "\\\$1" in
	start)
		status lsfpollerd  >/dev/null 2>&1
		if [ \\\$? -ne 0 ]; then
			echo -n "Starting LSF Poller Daemon "
			\\\$PROG_PATH\\\$PROG_BIN \\\$OPTIONS
			RETVAL=\\\$?
			[ \\\$RETVAL -eq 0 ] && touch /var/lock/subsys/lsfpollerd
			echo
		fi
		;;
	stop)
		echo -n "Shutting down LSF Poller Daemon "
		## Stop the grid collector processes first
		for lsfdir in \\\`find \\\$RTM_TOP/rtm -type d -name "lsf*" -prune\\\`; do
			for gridbin in \\\`find \\\$lsfdir/bin/ -type f -name "grid*" | grep -v grid.conf\\\`; do
				pid=\\\`pidof \\\$gridbin\\\`
				if [ "\\\$pid" != "" ]; then
					/bin/kill \\\$pid
				fi
			done
		done

		killproc \\\$PROG_BIN
		RETVAL=\\\$?
		[ \\\$RETVAL -eq 0 ] && rm -f /var/lock/subsys/lsfpollerd
		echo
		;;
	reload)
		echo -n "Reload service LSF Poller Daemon "
		\\\$0 stop
		\\\$0 start
		;;
	report)
		echo -n \\\$"Checking SMART devices now: "
		killproc \\\$SMARTD_BIN -USR1
		RETVAL=\\\$?
		echo
		;;
	restart)
		\\\$0 stop
		\\\$0 start
		;;
	status)
		echo -n "Checking for service LSF Poller Daemon "
		status \\\$PROG_BIN
		RETVAL=\\\$?
		;;
	*)
		echo \\\$"Usage: \\\$0 {start|stop|reload|report|restart|status}"
		RETVAL=1
	esac
	
	exit \$RETVAL
elif [ -f /etc/lsb-release ] ; then
	[ -f /lib/lsb/init-functions ] && . /lib/lsb/init-functions

	case "\\\$1" in
	start)
		echo -n "Starting LSF Poller Daemon "
		start-stop-daemon  --start --quiet --exec \\\$PROG_PATH\\\$PROG_BIN -- \\\\
			\\\$OPTIONS  \\\\
			|| RETVAL=2
		echo \\\$RETVAL
		RETVAL=0
		;;
	stop)
		echo -n "Shutting down LSF Poller Daemon "
		start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec \\\$PROG_PATH\\\$PROG_BIN
		[ "\\\$?" = 2 ] && return 2
		;;
	restart)
		echo -n "Reload service LSF Poller Daemon "
		\\\$0 stop
		\\\$0 start
		;;
	status)
		echo -n "Checking for service License Poller Daemon "
		status_of_proc  \\\$PROG_BIN && exit 0 || exit \\\$?
		RETVAL=\\\$?
	   	;;
	esac
	exit \\\$RETVAL
fi
EOF2

echo "Starting service lsfpollerd" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   chkconfig --add lsfpollerd >> \${LOG} 2>&1
   service lsfpollerd start >> \${LOG} 2>&1
;;
*debian*)
   /etc/init.d/lsfpollerd start >> \${LOG} 2>&1
;;
esac

echo "Creating desktop link" | tee -a \${LOG}
mkdir -p /root/Desktop
DESKTOP_LINK="/root/Desktop/RTM.desktop"
cat << EOF2 > \${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox http://localhost:8181/cacti
Name=RTM
Icon=firefox
EOF2

gio set \${DESKTOP_LINK} "metadata::trusted" true
chmod 755 "\${DESKTOP_LINK}"
EOF1
   chmod 755 /tmp/rtm_master.sh
}

write_rtm_howto () {
   cat >> /tmp/rtm_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_RTM.sh <<EOF2
#!/bin/sh

cat <<EOF3
Execute firefox http://localhost/cacti
Logon to the RTM web console with admin/admin
Set new password
Add (right upper corner, '+')
Mark 'LSF conf directory(Advanced)' (bottom)
Cluster Name: cluster1
LSF conf directory(Advanced)': /usr/share/lsf/conf
Create
EOF3
EOF2
   chmod 755 ~/HowTo_RTM.sh

   cat > ~/generate_random_load.sh <<EOF2
#!/bin/sh

# Generate random LSF jobs
# cwesthues@de.ibm.com
# 2024/05/31
# \\\$RANDOM=0-32767

SLOTS=\\\`sudo -i -u lsfadmin bhosts | egrep ok | awk 'BEGIN{S=0}{S=S+\\\$4}END{print S}'\\\`
PROJECTS="project_A project_B"
QUEUES="normal idle"
PEND=0
while true
do
   PEND=\\\`sudo -i -u lsfadmin bjobs -p 2>/dev/null | egrep PEND | wc -l\\\`
   if test "\\\${PEND}" -lt "\\\${SLOTS}"
   then
      PROJECT=\\\`echo \\\${PROJECTS} | awk '{print \\\$'\\\\\\\`expr \\\$RANDOM / 16383 + 1\\\\\\\`'}'\\\`
      QUEUE=\\\`echo \\\${QUEUES} | awk '{print \\\$'\\\\\\\`expr \\\$RANDOM / 16383 + 1\\\\\\\`'}'\\\`

      # sleep 0-30s, stress-ng 0-150s, sleep 0-30s
      # sudo -i -u lsfadmin bsub -q \\\${QUEUE} -P \\\${PROJECT} "sleep \\\`expr \\\\\\\$RANDOM / 1092\\\` ; stress-ng --cpu 1 --timeout \\\`expr \\\\\\\$RANDOM / 218\\\`s ; sleep \\\`expr \\\\\\\$RANDOM / 1092\\\`"

      # sleep 0-10min, stress-ng 0-50min., sleep 0-10min.
      sudo -i -u lsfadmin bsub -q \\\${QUEUE} -P \\\${PROJECT} "sleep \\\`expr \\\\\\\$RANDOM / 55\\\` ; stress-ng --cpu 1 --timeout \\\`expr \\\\\\\$RANDOM / 11\\\`s ; sleep \\\`expr \\\\\\\$RANDOM / 55\\\`"
   fi
   sleep 1
done
EOF2
   chmod 755 ~/generate_random_load.sh
EOF1
   chmod 755 /tmp/rtm_howto.sh
}

############################################################
######################### RTM end ##########################
############################################################

############################################################
################## Sanger-in-a-box start ###################
############################################################

write_sanger_in_a_box_master () {
   cat >> /tmp/sanger_in_a_box_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

SOFTWARE=\$1
LSF_TOP=\$2

echo | tee -a \${LOG}
echo "Argument 1 SOFTWARE: \${SOFTWARE}" | tee -a \${LOG}
echo "Argument 2 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Install Sanger-in-a-box" | tee -a \${LOG}

# Based upon:
# https://github.com/cancerit

#cwecwe

echo "Modify LSF configuration" | tee -a \${LOG}

LSF_CLUSTER_NAME=\`ls \${LSF_TOP}/conf/lsbatch\`
if test -f \${LSF_TOP}/conf/lsbatch/\${LSF_CLUSTER_NAME}/configdir/lsb.queues
then
   cat > \${LSF_TOP}/conf/lsbatch/\${LSF_CLUSTER_NAME}/configdir/lsb.queues <<EOF2
Begin Queue
QUEUE_NAME       = normal
FAIRSHARE        = USER_SHARES[[default,1]]
FAIRSHARE_QUEUES = basement small long week parallel
RES_REQ          = select[type==any] affinity[thread]
PRIORITY         = 40
INTERACTIVE      = YES
End Queue

Begin Queue
QUEUE_NAME       = basement
RES_REQ          = select[type==any] affinity[thread]
PRIORITY         = 41
INTERACTIVE      = YES
End Queue

Begin Queue
QUEUE_NAME       = small
RES_REQ          = select[type==any] affinity[thread]
PRIORITY         = 42
INTERACTIVE      = YES
End Queue

Begin Queue
QUEUE_NAME       = long
RES_REQ          = select[type==any] affinity[thread]
PRIORITY         = 43
INTERACTIVE      = YES
End Queue

Begin Queue
QUEUE_NAME       = week
RES_REQ          = select[type==any] affinity[thread]
PRIORITY         = 44
INTERACTIVE      = YES
End Queue

Begin Queue
QUEUE_NAME       = parallel
RES_REQ          = select[type==any] affinity[thread]
PRIORITY         = 45
INTERACTIVE      = YES
End Queue
EOF2
fi

if test "\${REGION}" = "onprem"
then
   echo "Restarting LSF" | tee -a \${LOG}
   RET=\`systemctl status lsfd 2>/dev/null\`
   if test "\${RET}" = ""
   then
      . \${LSF_TOP}/conf/profile.lsf
      lsf_daemons restart
   else
      systemctl restart lsfd
   fi
fi

echo "Installing some packages" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install \\
      autoconf automake bzip2 bzip2-devel cpan expat-devel gcc git gmp-devel \\
      gnutls-devel libcurl-devel libtasn1-devel make ncurses-devel \\
      nettle-devel perl-WWW-RobotRules perl-XML-LibXML python-devel \\
      xz-devel zlib-devel >> \${LOG} 2>&1
   crb enable >> \${LOG} 2>&1
   yum -y --nogpgcheck install R >> \${LOG} 2>&1
   PIP="pip"
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install \\
      autoconf automake build-essential gcc git gnutls-dev libbz2-dev \\
      libcpan-meta-perl libcurl4-openssl-dev libexpat-dev liblzma-dev \\
      libncurses5-dev libwww-robotrules-perl pkg-config make nettle-dev \\
      zlib1g-dev >> \${LOG} 2>&1
   apt -y -qq install r-base r-base-dev >> \${LOG} 2>&1
   PIP="pip3"
;;
esac

mkdir -p \${SOFTWARE}/CASM
ln -s \${SOFTWARE} /software

echo "########## htslib start ##########" | tee -a \${LOG}
# Depends on: none
echo "Cloning htslib" | tee -a \${LOG}
cd /tmp
git clone https://github.com/samtools/htslib >> \${LOG} 2>&1
cd htslib
echo "Setup htslib" | tee -a \${LOG}
git submodule update --init --recursive >> \${LOG} 2>&1
autoconf -i >> \${LOG} 2>&1
./configure >> \${LOG} 2>&1
make >> \${LOG} 2>&1
make install >> \${LOG} 2>&1
export LD_LIBRARY_PATH="/usr/local/lib:\${LD_LIBRARY_PATH}"
echo "export LD_LIBRARY_PATH=/usr/local/lib:\\\${LD_LIBRARY_PATH}" >> /root/.bashrc
echo "export LD_LIBRARY_PATH=/usr/local/lib:\\\${LD_LIBRARY_PATH}" >> /home/lsfadmin/.bashrc
echo "########## htslib end ##########" | tee -a \${LOG}

echo "########## samtools start ##########" | tee -a \${LOG}
# Depends on: htslib
echo "Cloning samtools" | tee -a \${LOG}
cd /tmp
git clone https://github.com/samtools/samtools >> \${LOG} 2>&1
cd samtools
echo "Setup samtools" | tee -a \${LOG}
autoheader >> \${LOG} 2>&1
autoconf -Wno-syntax >> \${LOG} 2>&1
./configure >> \${LOG} 2>&1
make >> \${LOG} 2>&1
make install >> \${LOG} 2>&1
echo "########## samtools end ##########" | tee -a \${LOG}

echo "########## bcftools start ##########" | tee -a \${LOG}
# Depends on: htslib
echo "Cloning bcftools" | tee -a \${LOG}
cd /tmp
git clone https://github.com/samtools/bcftools.git >> \${LOG} 2>&1
cd bcftools
echo "Setup bcftools" | tee -a \${LOG}
make >> \${LOG} 2>&1
make install >> \${LOG} 2>&1
echo "########## bcftools end ##########" | tee -a \${LOG}

echo "########## cgpBigWig start ##########" | tee -a \${LOG}
# Depends on: htslib
echo "Cloning cgpBigWig" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/cgpBigWig >> \${LOG} 2>&1
cd cgpBigWig
echo "Setup cgpBigWig" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/cgpBigWig >> \${LOG} 2>&1
export PATH="/software/CASM/cgpBigWig/bin:\${PATH}"
echo "export PATH=/software/CASM/cgpBigWig/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/cgpBigWig/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
echo "########## cgpBigWig end ##########" | tee -a \${LOG}

echo "########## PCAP-core start ##########" | tee -a \${LOG}
# Depends on: htslib cgpBigWig samtools
echo "Cloning PCAP-core" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/PCAP-core >> \${LOG} 2>&1
sed -i s#"https://iweb.dl.sourceforge.net/project/staden/staden/2.0.0b11/staden-2.0.0b11-2016-linux-x86_64.tar.gz"#"https://master.dl.sourceforge.net/project/staden/staden/2.0.0b11/staden-2.0.0b11-2016-linux-x86_64.tar.gz?viasf=1"#g /tmp/PCAP-core/setup.sh
cd PCAP-core
echo "Setup PCAP-core" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/PCAP-core >> \${LOG} 2>&1
export PATH="/software/CASM/PCAP-core/bin:\${PATH}"
echo "export PATH=/software/CASM/PCAP-core/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/PCAP-core/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
echo "########## PCAP-core end ##########" | tee -a \${LOG}

echo "########## ascatNgs start ##########" | tee -a \${LOG}
# Depends on: PCAP-core
echo "Cloning ascatNgs" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/ascatNgs >> \${LOG} 2>&1
cd ascatNgs
echo "Setup ascatNgs" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/ascatNgs >> \${LOG} 2>&1
export PATH="/software/CASM/ascatNgs/bin:\${PATH}"
echo "export PATH=/software/CASM/ascatNgs/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/ascatNgs/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
echo "########## ascatNgs end ##########" | tee -a \${LOG}

echo "########## cgpPindel start ##########" | tee -a \${LOG}
# Depends on: PCAP-core
echo "Cloning cgpPindel" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/cgpPindel >> \${LOG} 2>&1
cd cgpPindel
echo "Setup cgpPindel" | tee -a \${LOG}
#cwecwe
export CGP_PERLLIBS=/tmp/PCAP-core/lib
./setup.sh \${SOFTWARE}/CASM/cgpPindel >> \${LOG} 2>&1
export PATH="/software/CASM/cgpPindel/bin:\${PATH}"
echo "export PATH=/software/CASM/cgpPindel/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/cgpPindel/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
echo "########## cgpPindel end ##########" | tee -a \${LOG}

echo "########## CaVEMan start ##########" | tee -a \${LOG}
# Depends on: 
echo "Cloning CaVEMan" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/CaVEMan >> \${LOG} 2>&1
cd CaVEMan
echo "Setup CaVEMan" | tee -a \${LOG}
export LD_LIBRARY_PATH=""
./setup.sh \${SOFTWARE}/CASM/CaVEMan >> \${LOG} 2>&1
export PATH="/software/CASM/CaVEMan/bin:\${PATH}"
echo "export PATH=/software/CASM/CaVEMan/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/CaVEMan/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
echo "########## CaVEMan end ##########" | tee -a \${LOG}

echo "########## cgpBattenberg start ##########" | tee -a \${LOG}
# Depends on: 
echo "Cloning cgpBattenberg" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/cgpBattenberg >> \${LOG} 2>&1
cd cgpBattenberg
echo "Setup cgpBattenberg" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/cgpBattenberg >> \${LOG} 2>&1
export PATH="/software/CASM/cgpBattenberg/bin:\${PATH}"
echo "export PATH=/software/CASM/cgpBattenberg/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/cgpBattenberg/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
echo "########## cgpBattenberg end ##########" | tee -a \${LOG}

echo "########## cgpVcf start ##########" | tee -a \${LOG}
# Depends on: samtools
echo "Cloning cgpVcf" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/cgpVcf >> \${LOG} 2>&1
cd cgpVcf
echo "Setup cgpVcf" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/cgpVcf >> \${LOG} 2>&1
export PATH="/software/CASM/cgpVcf/bin:\${PATH}"
echo "export PATH=/software/CASM/cgpVcf/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/cgpVcf/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
export CGP_PERLLIBS="/software/CASM/cgpVcf/lib/perl5:\${CGP_PERLLIBS}"
echo "export CGP_PERLLIBS=/software/CASM/cgpVcf/lib/perl5:\\\${CGP_PERLLIBS}" >> /root/.bashrc
echo "export CGP_PERLLIBS=/software/CASM/cgpVcf/lib/perl5:\\\${CGP_PERLLIBS}" >> /home/lsfadmin/.bashrc
echo "########## cgpVcf end ##########" | tee -a \${LOG}

echo "########## VAGrENT start ##########" | tee -a \${LOG}
# Depends on: none
echo "Cloning VAGrENT" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/VAGrENT >> \${LOG} 2>&1
cd VAGrENT
echo "Setup VAGrENT" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/VAGrENT >> \${LOG} 2>&1
export PATH="/software/CASM/VAGrENT/bin:\${PATH}"
echo "export PATH=/software/CASM/VAGrENT/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/VAGrENT/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
export CGP_PERLLIBS="/software/CASM/VAGrENT/lib/perl5:\${CGP_PERLLIBS}"
echo "export CGP_PERLLIBS=/software/CASM/VAGrENT/lib/perl5:\\\${CGP_PERLLIBS}" >> /root/.bashrc
echo "export CGP_PERLLIBS=/software/CASM/VAGrENT/lib/perl5:\\\${CGP_PERLLIBS}" >> /home/lsfadmin/.bashrc
echo "########## VAGrENT end ##########" | tee -a \${LOG}

echo "########## grass start ##########" | tee -a \${LOG}
# Depends on: none
echo "Cloning grass" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/grass >> \${LOG} 2>&1
cd grass
echo "Setup grass" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/grass >> \${LOG} 2>&1
export PATH="/software/CASM/grass/bin:\${PATH}"
echo "export PATH=/software/CASM/grass/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/grass/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
export CGP_PERLLIBS="/software/CASM/grass/lib/perl5:\${CGP_PERLLIBS}"
echo "export CGP_PERLLIBS=/software/CASM/grass/lib/perl5:\\\${CGP_PERLLIBS}" >> /root/.bashrc
echo "export CGP_PERLLIBS=/software/CASM/grass/lib/perl5:\\\${CGP_PERLLIBS}" >> /home/lsfadmin/.bashrc
echo "########## grass end ##########" | tee -a \${LOG}

echo "########## BRASS start ##########" | tee -a \${LOG}
# Depends on: none
case \${ID_LIKE} in
*debian*)
   ln -s /usr/bin/python3 /usr/bin/python
;;
esac
echo "Cloning BRASS" | tee -a \${LOG}
cd /tmp
git clone https://github.com/cancerit/BRASS >> \${LOG} 2>&1
cd BRASS
# Little hack, CWE
sed -i s/"PCAP"/"Sanger::CGP::Grass"/g setup.sh
echo "Setup BRASS" | tee -a \${LOG}
./setup.sh \${SOFTWARE}/CASM/BRASS >> \${LOG} 2>&1
echo "export PATH=/software/CASM/BRASS/bin:\\\${PATH}" >> /root/.bashrc
echo "export PATH=/software/CASM/BRASS/bin:\\\${PATH}" >> /home/lsfadmin/.bashrc
echo "########## BRASS end ##########" | tee -a \${LOG}

echo "########## gridss start ##########" | tee -a \${LOG}
# Depends on: none
echo "Cloning gridss" | tee -a \${LOG}
cd /tmp
git clone --recurse-submodules http://github.com/PapenfussLab/gridss >> \${LOG} 2>&1
cd gridss/src/main/c/gridsstools/htslib
echo "Setup gridss" | tee -a \${LOG}
autoreconf -i && ./configure && make >> \${LOG} 2>&1
cd ..
autoreconf -i && ./configure && make all >> \${LOG} 2>&1
cp /tmp/gridss/src/main/c/gridsstools/gridsstools /usr/bin
echo "########## gridss end ##########" | tee -a \${LOG}

echo "########## cgpwgs-nf start ##########" | tee -a \${LOG}
# Depends on: samtools
echo "Cloning cgpwgs-nf" | tee -a \${LOG}
cd \${SOFTWARE}/CASM/
git clone https://github.com/HealthInnovationEast/cgpwgs-nf >> \${LOG} 2>&1
sed -i s/"slurm.config'}"/"slurm.config'}\n    lsf {includeConfig 'conf\/lsf.config'}"/g cgpwgs-nf/nextflow.config
cat >> cgpwgs-nf/conf/lsf.config <<EOF2
executor {
    name = 'lsf'
}
EOF2
echo "########## cgpwgs-nf end ##########" | tee -a \${LOG}

EOF1
   chmod 755 /tmp/sanger_in_a_box_master.sh
}

write_sanger_in_a_box_compute () {
   cat >> /tmp/sanger_in_a_box_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

SOFTWARE=\$1

echo | tee -a \${LOG}
echo "Argument 1 SOFTWARE: \${SOFTWARE}" | tee -a \${LOG}
echo | tee -a \${LOG}

ln -s \${SOFTWARE} /software

EOF1
   chmod 755 /tmp/sanger_in_a_box_compute.sh
}

write_sanger_in_a_box_howto () {
   cat >> /tmp/sanger_in_a_box_howto.sh <<EOF1
#!/bin/sh

SOFTWARE=\$1

echo | tee -a \${LOG}
echo "Argument 1 SOFTWARE: \${SOFTWARE}" | tee -a \${LOG}
echo | tee -a \${LOG}

cat >> ~/HowTo_Sanger-in-a-box.sh <<EOF2
#!/bin/sh

. /etc/os-release
. /var/environment.sh

export LD_LIBRARY_PATH=/usr/local/lib:\\\$LD_LIBRARY_PATH

case \\\${ID_LIKE} in
*rhel*|*fedora*)
   ESC="-e"
;;
*debian*)
;;
esac

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

echo
echo \\\${ESC} "\\\${BLUE}Check htslib:\\\${OFF}"
echo "   ls -al /usr/local/lib/libhts*"
ls -al /usr/local/lib/libhts*

echo
echo \\\${ESC} "\\\${BLUE}Check samtools:\\\${OFF}"
echo "   samtools 2>&1 | head -3"
samtools 2>&1 | head -3

echo
echo \\\${ESC} "\\\${BLUE}Check bcftools:\\\${OFF}"
echo "   bcftools --version"
bcftools --version

echo
echo \\\${ESC} "\\\${BLUE}Check cgpBigWig:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/cgpBigWig/bin"
ls -al \${SOFTWARE}/CASM/cgpBigWig/bin | head -6 | tail -3
echo "..."
ls -al \${SOFTWARE}/CASM/cgpBigWig/bin | tail -3

echo
echo \\\${ESC} "\\\${BLUE}Check ascatNgs:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/ascatNgs/bin"
ls -al \${SOFTWARE}/CASM/ascatNgs/bin | head -6 | tail -3
echo "..."
ls -al \${SOFTWARE}/CASM/ascatNgs/bin | tail -3

echo
echo \\\${ESC} "\\\${BLUE}Check cgpPindel:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/cgpPindel/bin"
ls -al \${SOFTWARE}/CASM/cgpPindel/bin | head -6 | tail -3
echo "..."
ls -al \${SOFTWARE}/CASM/cgpPindel/bin | tail -3

echo
echo \\\${ESC} "\\\${BLUE}Check CaVEMan:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/CaVEMan/bin"
ls -al \${SOFTWARE}/CASM/CaVEMan/bin

echo
echo \\\${ESC} "\\\${BLUE}Check cgpBattenberg:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/cgpBattenberg/bin"
ls -al \${SOFTWARE}/CASM/cgpBattenberg/bin | head -6 | tail -3
echo "..."
ls -al \${SOFTWARE}/CASM/cgpBattenberg/bin | tail -3

echo
echo \\\${ESC} "\\\${BLUE}Check cgpVcf:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/cgpVcf/bin"
ls -al \${SOFTWARE}/CASM/cgpVcf/bin | head -6 | tail -3
echo "..."
ls -al \${SOFTWARE}/CASM/cgpVcf/bin | tail -3

echo
echo \\\${ESC} "\\\${BLUE}Check VAGrENT:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/VAGrENT/bin"
ls -al \${SOFTWARE}/CASM/VAGrENT/bin | head -6 | tail -3
echo "..."
ls -al \${SOFTWARE}/CASM/VAGrENT/bin | tail -3

echo
echo \\\${ESC} "\\\${BLUE}Check grass:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/grass/bin"
ls -al \${SOFTWARE}/CASM/grass/bin

echo
echo \\\${ESC} "\\\${BLUE}Check BRASS:\\\${OFF}"
echo "   ls -al \${SOFTWARE}/CASM/BRASS/bin"
ls -al \${SOFTWARE}/CASM/BRASS/bin | head -6 | tail -3
echo "..."
ls -al \${SOFTWARE}/CASM/BRASS/bin | tail -3

echo
echo \\\${ESC} "\\\${BLUE}Check gridss:\\\${OFF}"
echo "   gridsstools -v"
gridsstools -v

EOF2
chmod 755 ~/HowTo_Sanger-in-a-box.sh

cat >> ~/HowTo_cgpwgs-nf.sh <<EOF2
#!/bin/sh

. /etc/os-release
. /var/environment.sh

export LD_LIBRARY_PATH=/usr/local/lib:\\\$LD_LIBRARY_PATH

case \\\${ID_LIKE} in
*rhel*|*fedora*)
   ESC="-e"
;;
*debian*)
;;
esac

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

if test ! -d \${SOFTWARE}/CASM/cgpwgs-nf/GRCh37/archives
then
   echo
   echo \\\${ESC} "\\\${BLUE}Download: (approx. 30 min.)\\\${OFF}"
   cd \${SOFTWARE}/CASM/cgpwgs-nf
   mkdir -p GRCh37/archives
   cd GRCh37/archives
   echo "   Getting GRCh37"
   wget ftp.sanger.ac.uk/pub/cancer/dockstore/human/{core_ref_GRCh37d5.tar.gz,VAGrENT_ref_GRCh37d5_ensembl_75.tar.gz,CNV_SV_ref_GRCh37d5_brass6+.tar.gz,SNV_INDEL_ref_GRCh37d5-fragment.tar.gz,qcGenotype_GRCh37d5.tar.gz} 1>/dev/null 2>/dev/null
   echo "   Getting GRCh38"
   wget ftp.sanger.ac.uk/pub/cancer/dockstore/human/GRCh38_hla_decoy_ebv/{core_ref_GRCh38_hla_decoy_ebv.tar.gz,VAGrENT_ref_GRCh38_hla_decoy_ebv_ensembl_91.tar.gz,CNV_SV_ref_GRCh38_hla_decoy_ebv_brass6+.tar.gz,qcGenotype_GRCh38_hla_decoy_ebv.tar.gz,SNV_INDEL_ref_GRCh38_hla_decoy_ebv-fragment.tar.gz} 1>/dev/null 2>/dev/null
   echo "   Getting test data"
   wget http://ngs.sanger.ac.uk/production/cancer/dockstore/cgpwgs/sampled/COLO-829.{bam,bam.bai,bam.bas} 1>/dev/null 2>/dev/null
   wget http://ngs.sanger.ac.uk/production/cancer/dockstore/cgpwgs/sampled/COLO-829-BL.{bam,bam.bai,bam.bas} 1>/dev/null 2>/dev/null
fi

export PROFILES="lsf"
export PATH_TO_REF="\${SOFTWARE}/CASM/cgpwgs-nf/GRCh37/archives"
export PATH_TO_UPDATED_CSV="\${SOFTWARE}/CASM/cgpwgs-nf/data"

export PATH="\\\${PATH}:\${SOFTWARE}/CASM/PCAP-core/bin:\${SOFTWARE}/CASM/VAGrENT/bin"

cd \${SOFTWARE}/CASM/cgpwgs-nf
echo "Running nextflow"
nextflow run main.nf \\\
   -profile \\\$PROFILES \\\
   --core_ref \\\$PATH_TO_REF/core_ref_GRCh37d5.tar.gz \\\\
   --snv_indel \\\$PATH_TO_REF/SNV_INDEL_ref_GRCh37d5-fragment.tar.gz \\\\
   --cvn_sv \\\$PATH_TO_REF/CNV_SV_ref_GRCh37d5_brass6+.tar.gz \\\\
   --annot \\\$PATH_TO_REF/VAGrENT_ref_GRCh37d5_ensembl_75.tar.gz \\\\
   --qc_genotype \\\$PATH_TO_REF/qcGenotype_GRCh37d5.tar.gz \\\\
   --pairs \\\$PATH_TO_UPDATED_CSV/test.csv
EOF2
chmod 755 ~/HowTo_cgpwgs-nf.sh
EOF1
   chmod 755 /tmp/sanger_in_a_box_howto.sh
}

############################################################
################### Sanger-in-a-box end ####################
############################################################

############################################################
#################### ScaleClient start #####################
############################################################

write_scaleclient() {
   cat >> /tmp/scaleclient.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

cd /tmp
echo "Downloading Scale tarball from box" | tee -a \${LOG}
echo "   Scale_std_install-5.2.0.0_x86_64.tar.gz" | tee -a \${LOG}
curl -Lo Scale_std_install-5.2.0.0_x86_64.tar.gz https://ibm.box.com/shared/static/9kta6q4jkio651xxejgyusy2puzhy8n4.gz >> \${LOG} 2>&1

echo "Unpack Scale_std_install-5.2.0.0_x86_64.tar.gz" | tee -a \${LOG}
tar xzf Scale_std_install-5.2.0.0_x86_64.tar.gz >> \${LOG} 2>&1

chmod 755 Storage_Scale_Standard-5.2.0.0-x86_64-Linux-install
./Storage_Scale_Standard-5.2.0.0-x86_64-Linux-install --silent >> \${LOG} 2>&1

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "Preparing node" | tee -a \${LOG}
   cat >> /etc/os-release << EOF2
NAME="Red Hat Enterprise Linux"
VERSION="9.3 (Plow)"
ID="rhel"
ID_LIKE="fedora"
VERSION_ID="9.3"
PLATFORM_ID="platform:el9"
PRETTY_NAME="Red Hat Enterprise Linux 9.3 (Plow)"
ANSI_COLOR="0;31"
LOGO="fedora-logo-icon"
CPE_NAME="cpe:/o:redhat:enterprise_linux:9::baseos"
HOME_URL="https://www.redhat.com/" 
DOCUMENTATION_URL="https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9"
BUG_REPORT_URL="https://bugzilla.redhat.com/"

REDHAT_BUGZILLA_PRODUCT="Red Hat Enterprise Linux 9"
REDHAT_BUGZILLA_PRODUCT_VERSION=9.3
REDHAT_SUPPORT_PRODUCT="Red Hat Enterprise Linux"
REDHAT_SUPPORT_PRODUCT_VERSION="9.3"
EOF2
   cat >> /etc/system-release << EOF2
Red Hat Enterprise Linux release 9.3 (Plow)
EOF2

   ### CAREFULL, Scale will change the openssh version, we have to reset it AFTER
   OLD_SSH_VERSION=\`rpm -qa | egrep -i openssl-libs | awk 'BEGIN{FS="-"}{printf("%s-%s-%s\n",\$1,\$2,\$3)}'\`
   echo "OLD_SSH_VERSION is \${OLD_SSH_VERSION}" | tee -a \${LOG}

   cd /usr/lpp/mmfs/5.2.0.0/gpfs_rpms
   yum -y install make gcc gcc-c++ >> \${LOG} 2>&1
   RELEASE=\`uname -r\`
   case \${RELEASE} in
   5.14.0-362.8.1.el9_3.x86_64)
      # Almalinux9.3
      #yum -y install https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/kernel-headers-5.14.0-362.8.1.el9_3.x86_64.rpm >> \${LOG} 2>&1
      yum -y install https://ibm.box.com/shared/static/ymuzzvgw43rblpjhvpxn8y829tl68a79.rpm >> \${LOG} 2>&1
      #yum -y install https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/kernel-devel-5.14.0-362.8.1.el9_3.x86_64.rpm >> \${LOG} 2>&1
      yum -y install https://ibm.box.com/shared/static/bvcj7kgkzvo89dwizk4urc4hkf51xy8p.rpm >> \${LOG} 2>&1
   ;;
   5.14.0-252.el9.x86_64)
      # CentOS9 stream
      yum -y install kernel-devel kernel-headers >> \${LOG} 2>&1
   ;;
   esac
   yum -y install gpfs.base*.rpm gpfs.gpl*.rpm gpfs.gskit*.rpm gpfs.msg.en_US*.rpm gpfs.license.*.rpm
;;  
*debian*)
   cd /usr/lpp/mmfs/5.2.0.0/gpfs_debs
   apt -y update >> \${LOG} 2>&1
   apt -y -qq install make gcc g++ >> \${LOG} 2>&1
   apt -y reinstall linux-hwe-6.2-headers-6.2.0-33 linux-headers-\$(uname -r) >> \${LOG} 2>&1
   apt -y -qq install ./gpfs.base*.deb ./gpfs.gpl*.deb ./gpfs.gskit*.deb ./gpfs.msg.en-us*.deb ./gpfs.license.*.deb >> \${LOG} 2>&1
   export LD_LIBRARY_PATH=/usr/lpp/mmfs/lib
;;
esac

/usr/lpp/mmfs/bin/mmbuildgpl >> \${LOG} 2>&1

### CAREFULL, restoring openssh
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y install \${OLD_SSH_VERSION} >> \${LOG} 2>&1
;;
esac

EOF1
   chmod 755 /tmp/scaleclient.sh
}

############################################################
##################### ScaleClient end ######################
############################################################

############################################################
##################### Simulator start ######################
############################################################

write_simulator_master () {
   cat >> /tmp/simulator_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"
TOP="/opt/ibm"

echo "Installing docker-ce" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   rpm -e podman-docker >> \${LOG} 2>&1
   yum config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo >> \${LOG} 2>&1
   yum -y install docker-ce >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - >> \${LOG} 2>&1
   add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" >> \${LOG} 2>&1
   apt-get install -y -qq docker-ce docker-ce-cli containerd.io >> \${LOG} 2>&1
;;
esac
systemctl enable docker >> \${LOG} 2>&1
systemctl start docker >> \${LOG} 2>&1

echo "Pulling docker:dind" | tee -a \${LOG}
docker pull docker:dind >> \${LOG} 2>&1

echo "Downloading Simulator tarball from box" | tee -a \${LOG}
cd /tmp
echo "  lsf_cognitive_simulator_v1.tar.gz" | tee -a \${LOG}
curl -Lo lsf_cognitive_simulator_v1.tar.gz https://ibm.box.com/shared/static/l0i6nfi069yrwn40x85tqi5o23o2mir3.gz | tee -a \${LOG}

mkdir -p /shared
mkdir -p \${TOP}
cd \${TOP}
echo "Extracting lsf_cognitive_v1.tar.Z" | tee -a \${LOG}
tar xzf /tmp/lsf_cognitive_simulator_v1.tar.gz >> \${LOG} 2>&1
chown -R lsfadmin:lsfadmin \${TOP}

echo "Running bcogn" | tee -a \${LOG}
cd \${TOP}
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p >> \${LOG} 2>&1
usermod -a -G docker lsfadmin

echo "Creating service simulator" | tee -a \${LOG}
cat > /usr/bin/simulator.sh <<EOF2
#!/bin/sh

export USER="root"
for CONT in \\\`docker ps -aq\\\`
do
   docker stop \\\${CONT}
   docker rm \\\${CONT}
done
cd \${TOP}/lsf_cognitive_v1
sudo -i -u lsfadmin \${TOP}/lsf_cognitive_v1/bcogn start -v "/usr/share/lsf:/usr/share/lsf" -v "/shared:/shared"
EOF2
chmod 755 /usr/bin/simulator.sh

cat > /etc/systemd/system/simulator.service <<EOF2
[Unit]
Description=IBM LSF Simulator
After=network.target nfs.service autofs.service gpfs.service

[Service]
Type=forking
ExecStart=/usr/bin/simulator.sh start
ExecStop=/usr/bin/simulator.sh stop
TimeoutSec=100000

[Install]
WantedBy=multi-user.target
EOF2
systemctl enable simulator

touch \${TOP}/lsf_cognitive_v1/License/.acceptance

sudo -i -u lsfadmin \${TOP}/lsf_cognitive_v1/bcogn start -v "/usr/share/lsf:/usr/share/lsf" -v "/shared:/shared"

echo "Add certificate" | tee -a \${LOG}
case \${ID_LIKE} in
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt-get install -y -qq libnss3-tools >> \${LOG} 2>&1
;;
esac
for certDB in \$(find ~/ -name "cert9.db")
do
   certdir=\$(dirname \${certDB});
   certutil -A -n "IBM LSF Simulator" -t "TCu,Cu,Tu" -i /opt/ibm/lsf_cognitive_v1/config/https/cacert_lsf.pem -d sql:\${certdir} >> \${LOG} 2>&1
done

echo "Create /tmp/lsf_simulator.tar.gz" | tee -a \${LOG}
docker run -it --rm -v "/tmp:/copyto" lsf_simulator:v1 tar zcf /copyto/lsf_simulator.tar.gz /opt/ibm/lsf_simulator


echo "Creating desktop link" | tee -a \${LOG}
DESKTOP_LINK="/root/Desktop/Simulator.desktop"
cat << EOF2 > \${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox https://\`hostname\`:5050
Name=Simulator
Icon=firefox
EOF2

gio set \${DESKTOP_LINK} "metadata::trusted" true
chmod 755 "\${DESKTOP_LINK}"
EOF1
   chmod 755 /tmp/simulator_master.sh
}

write_simulator_howto () {
   cat >> /tmp/simulator_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_LSF-Simulator.sh <<EOF2
#!/bin/sh

cat <<EOF3

Execute firefox https://\`hostname\`:5050
Logon to the Simulator web console with Admin/Admin
Cluster Configurations
Import
Configuration name: cluster1
LOCAL:    LSF conf directory ...: /usr/share/lsf/conf
REMOTE:   LSF conf directory ...: /shared/remote_conf.tar.gz
Import
Workload Snapshots
Import
Workload Snapshot Name: Snapshot1
LOCAL:    LSF events log diectory: /usr/share/lsf/work/cluster1/logdir
REMOTE:   LSF events log diectory: /shared/remote_logdir
Associate a Cluster Configuration: cluster1
Import
(takes some time, refresh...)
Experiments
Create
Experiment1
Select Cluster Configuration: cluster1
Next
Select Workload Snapshot: Snapshot1
Next
Run
(takes some time, refresh...)
Look at:
Experiment Results
Graphs
EOF3
EOF2
chmod 755 ~/HowTo_LSF-Simulator.sh
EOF1
   chmod 755 /tmp/simulator_howto.sh
}

############################################################
###################### Simulator end #######################
############################################################

############################################################
####################### SLURM start ########################
############################################################

# Based upon:
# https://www.ni-sp.com/slurm-build-script-and-container-commercial-support/

write_slurm_master () {
   cat >> /tmp/slurm_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

MASTER=\$1
MUNGE_KEY=\$2
VER="23.11.4"

echo | tee -a \${LOG}
echo "Argument 1 MASTER: \${MASTER}" | tee -a \${LOG}
echo "Argument 2 MUNGE_KEY: \${MUNGE_KEY}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Install munge" | tee -a \${LOG}

export MUNGEUSER=966
groupadd -g \$MUNGEUSER munge >> \${LOG} 2>&1
useradd  -m -d /var/lib/munge -u \$MUNGEUSER -g munge  -s /sbin/nologin munge >> \${LOG} 2>&1
export SLURMUSER=967
groupadd -g \$SLURMUSER slurm >> \${LOG} 2>&1
useradd  -m -d /var/lib/slurm -u \$SLURMUSER -g slurm  -s /bin/bash slurm >> \${LOG} 2>&1

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm >> \${LOG} 2>&1
   yum -y --nogpgcheck install munge munge-libs >> \${LOG} 2>&1
   dnf -y --enablerepo=crb install mariadb-devel munge-devel >> \${LOG} 2>&1
   yum -y --nogpgcheck install rng-tools >> \${LOG} 2>&1
   rngd -r /dev/urandom >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install munge libmunge-dev libmunge2 rng-tools >> \${LOG} 2>&1
   rngd -r /dev/urandom >> \${LOG} 2>&1
;;
esac

#/usr/sbin/create-munge-key -r -f >> \${LOG} 2>&1
#sh -c  "dd if=/dev/urandom bs=1 count=1024 >> /etc/munge/munge.key 2>/dev/null"
# To generate munge key string:
#sh -c  "dd if=/dev/urandom bs=1 count=32 >> /etc/munge/munge.key 2>/dev/null"
#cat /etc/munge/munge.key | base64 -w0

echo "\${MUNGE_KEY}" | base64 -d >> /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
systemctl enable munge >> \${LOG} 2>&1
systemctl restart munge >> \${LOG} 2>&1

echo "Install mariadb" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install mariadb-server dnf >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install mariadb-server libmariadb-dev-compat libmariadb-dev >> \${LOG} 2>&1
;;
esac

cat >> /etc/my.cnf <<EOF2
[mysqld]
innodb_buffer_pool_size=4096M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
max_allowed_packet=16M
EOF2

systemctl enable mariadb >> \${LOG} 2>&1
systemctl start mariadb >> \${LOG} 2>&1

echo "grant all on slurm_acct_db.* TO 'slurm'@'localhost' identified by 'password' with grant option;" | mysql -uroot -proot
echo "create database slurm_acct_db;" | mysql -uroot -proot >> \${LOG} 2>&1

echo "Compiling slurm" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   #mkdir -p ${LOC}/SW/ONPREM/SLURM
   yum -y --nogpgcheck install gtk2-devel >> \${LOG} 2>&1 # for sview 
   yum -y --nogpgcheck install python3 gcc openssl openssl-devel pam-devel numactl numactl-devel hwloc lua readline-devel ncurses-devel man2html libibmad libibumad rpm-build  perl-ExtUtils-MakeMaker.noarch perl-devel dbus-devel >> \${LOG} 2>&1
   yum -y --nogpgcheck install rpm-build make >> \${LOG} 2>&1
   dnf -y --enablerepo=crb install rrdtool-devel lua-devel hwloc-devel >> \${LOG} 2>&1
   mkdir -p /tmp/slurm-tmp
   cd /tmp/slurm-tmp
   rm -rf slurm-\${VER}.tar.bz2
   wget https://download.schedmd.com/slurm/slurm-\${VER}.tar.bz2 >> \${LOG} 2>&1
   echo "Running rpmbuild" | tee -a \${LOG}
   rpmbuild -ta slurm-\$VER.tar.bz2 --define '_lto_cflags %{nil}' >> \${LOG} 2>&1
   rm slurm-\$VER.tar.bz2 >> \${LOG} 2>&1
   cd ..
   rmdir /tmp/slurm-tmp >> \${LOG} 2>&1
   #cp -r ~/rpmbuild/RPMS/x86_64/* ${LOC}/SW/ONPREM/SLURM
;;
*debian*)
   #mkdir -p ${LOC}/SW/ONPREM/SLURM
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install python3 gcc openssl numactl hwloc lua5.3 man2html make ruby ruby-dev libmunge-dev libpam0g-dev libdbus-1-dev >> \${LOG} 2>&1
   /usr/bin/gem install fpm >> \${LOG} 2>&1
   cd
   rm -rf /tmp/slurm-tmp
   mkdir -p /tmp/slurm-tmp
   cd /tmp/slurm-tmp
   rm -rf slurm-*
   wget --no-check-certificate https://download.schedmd.com/slurm/slurm-\${VER}.tar.bz2 >> \${LOG} 2>&1
   tar jxvf slurm-\${VER}.tar.bz2 >> \${LOG} 2>&1
   cd  slurm-[0-9]*.[0-9]
   ./configure --sysconfdir=/etc/slurm --enable-pam --with-pam_dir=/lib/x86_64-linux-gnu/security/ --without-shared-libslurm >> \${LOG} 2>&1
   make >> \${LOG} 2>&1
   make contrib >> \${LOG} 2>&1
   make install >> \${LOG} 2>&1
   cd ..
;;
esac

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "Install slurm" | tee -a \${LOG}
   cd ~/rpmbuild/RPMS/x86_64
   yum -y --nogpgcheck localinstall *.rpm >> \${LOG} 2>&1
;;
esac

echo "Confirure slurm" | tee -a \${LOG}

mkdir -p /etc/slurm

cat >> /etc/slurm/slurm.conf << EOF2
SlurmctldHost=\${MASTER}
MpiDefault=none
ProctrackType=proctrack/cgroup
ReturnToService=1
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
SlurmdSpoolDir=/var/spool/slurm/slurmd
SlurmUser=slurm
StateSaveLocation=/var/spool/slurm
SwitchType=switch/none
TaskPlugin=task/affinity
SchedulerType=sched/backfill
#SelectType=select/cons_res
SelectTypeParameters=CR_Core
AccountingStorageType=accounting_storage/slurmdbd
ClusterName=cluster
JobAcctGatherType=jobacct_gather/none
PartitionName=test Nodes=ALL MaxTime=INFINITE Default=Yes State=Up
SrunPortRange=63000-64000

# For dyn. hosts:
TreeWidth=65533
MaxNodeCount=100
SelectType=select/cons_tres
EOF2

cat >> /etc/slurm/slurmdbd.conf << EOF2
AuthType=auth/munge
DbdAddr=localhost
DbdHost=localhost
SlurmUser=slurm
DebugLevel=verbose
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/var/run/slurmdbd.pid
StorageType=accounting_storage/mysql
StoragePass=password
StorageUser=slurm
EOF2
chown slurm:slurm /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf
cat >> /etc/slurm/cgroup.conf << EOF2
#CgroupAutomount=yes
#CgroupPlugin=cgroup/v1
ConstrainCores=no
ConstrainRAMSpace=no
EOF2

mkdir -p /var/spool/slurm
chown slurm:slurm /var/spool/slurm
chmod 755 /var/spool/slurm
mkdir -p /var/spool/slurm/slurmctld
chown slurm:slurm /var/spool/slurm/slurmctld
chmod 755 /var/spool/slurm/slurmctld
mkdir -p /var/spool/slurm/cluster_state
chown slurm:slurm /var/spool/slurm/cluster_state
touch /var/log/slurmctld.log
chown slurm:slurm /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
chown slurm: /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
mkdir -p /var/spool/slurm/slurmd
chown slurm:slurm /var/spool/slurm/slurmd
chmod 755 /var/spool/slurm/slurmd

case \${ID_LIKE} in
*debian*)
   cat >> /etc/systemd/system/slurmctld.service <<EOF2
[Unit]
Description=Slurm controller daemon
After=network.target munge.service
ConditionPathExists=/etc/slurm/slurm.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmctld
ExecStart=/usr/local/sbin/slurmctld $SLURMCTLD_OPTIONS
ExecReload=/bin/kill -HUP \\\$MAINPID
PIDFile=/var/run/slurmctld.pid

[Install]
WantedBy=multi-user.target
EOF2
   cat >> /etc/systemd/system/slurmdbd.service <<EOF2
[Unit]
Description=Slurm DBD accounting daemon
After=network.target munge.service
ConditionPathExists=/etc/slurm/slurmdbd.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmdbd
ExecStart=/usr/local/sbin/slurmdbd \$SLURMDBD_OPTIONS
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=/var/run/slurmdbd.pid

[Install]
WantedBy=multi-user.target
EOF2

   cat >> /etc/systemd/system/slurmd.service <<EOF2
[Unit]
Description=Slurm node daemon
After=network.target munge.service
ConditionPathExists=/etc/slurm/slurm.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmd
ExecStart=/usr/local/sbin/slurmd -d /usr/local/sbin/slurmstepd $SLURMD_OPTIONS
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=/var/run/slurmd.pid
KillMode=process
LimitNOFILE=51200
LimitMEMLOCK=infinity
LimitSTACK=infinity

[Install]
WantedBy=multi-user.target
EOF2
;;
esac

echo "Starting slurm" | tee -a \${LOG}

systemctl enable slurmctld >> \${LOG} 2>&1
systemctl start slurmctld >> \${LOG} 2>&1
systemctl enable slurmdbd >> \${LOG} 2>&1
systemctl start slurmdbd >> \${LOG} 2>&1
echo "Sleep for a few seconds for slurmd to come up ..." | tee -a \${LOG}
sleep 3
chmod 777 /var/spool   # hack for now as otherwise slurmctld is complaining
systemctl start slurmctld.service
echo "Sleep for a few seconds for slurmctld to come up ..." | tee -a \${LOG}
sleep 3

EOF1
   chmod 755 /tmp/slurm_master.sh
}

write_slurm_compute () {
   cat >> /tmp/slurm_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

MASTER=\$1
MUNGE_KEY=\$2
VER="23.11.4"

echo | tee -a \${LOG}
echo "Argument 1 MASTER: \${MASTER}" | tee -a \${LOG}
echo "Argument 2 MUNGE_KEY: \${MUNGE_KEY}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Install munge" | tee -a \${LOG}

export MUNGEUSER=966
groupadd -g \$MUNGEUSER munge >> \${LOG} 2>&1
useradd  -m -d /var/lib/munge -u \$MUNGEUSER -g munge  -s /sbin/nologin munge >> \${LOG} 2>&1
export SLURMUSER=967
groupadd -g \$SLURMUSER slurm >> \${LOG} 2>&1
useradd  -m -d /var/lib/slurm -u \$SLURMUSER -g slurm  -s /bin/bash slurm >> \${LOG} 2>&1

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm >> \${LOG} 2>&1
   yum -y --nogpgcheck install munge munge-libs >> \${LOG} 2>&1
   dnf -y --enablerepo=crb install mariadb-devel munge-devel >> \${LOG} 2>&1
   yum -y --nogpgcheck install rng-tools >> \${LOG} 2>&1
   rngd -r /dev/urandom >> \${LOG} 2>&1
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install munge libmunge-dev libmunge2 rng-tools >> \${LOG} 2>&1
   rngd -r /dev/urandom >> \${LOG} 2>&1
;;
esac

#/usr/sbin/create-munge-key -r -f >> \${LOG} 2>&1
#sh -c  "dd if=/dev/urandom bs=1 count=1024 >> /etc/munge/munge.key 2>/dev/null"
# To generate munge key string:
#sh -c  "dd if=/dev/urandom bs=1 count=32 >> /etc/munge/munge.key 2>/dev/null"
#cat /etc/munge/munge.key | base64 -w0

echo "\${MUNGE_KEY}" | base64 -d >> /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
systemctl enable munge >> \${LOG} 2>&1
systemctl restart munge >> \${LOG} 2>&1

echo "Compiling slurm" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install gtk2-devel >> \${LOG} 2>&1 # for sview
   yum -y --nogpgcheck install python3 gcc openssl openssl-devel pam-devel numactl numactl-devel hwloc lua readline-devel ncurses-devel man2html libibmad libibumad rpm-build  perl-ExtUtils-MakeMaker.noarch perl-devel dbus-devel >> \${LOG} 2>&1
   yum -y --nogpgcheck install rpm-build make >> \${LOG} 2>&1
   dnf -y --enablerepo=crb install rrdtool-devel lua-devel hwloc-devel >> \${LOG} 2>&1
   mkdir -p /tmp/slurm-tmp
   cd /tmp/slurm-tmp
   rm -rf slurm-\${VER}.tar.bz2
   wget https://download.schedmd.com/slurm/slurm-\${VER}.tar.bz2 >> \${LOG} 2>&1
   echo "Running rpmbuild" | tee -a \${LOG}
   rpmbuild -ta slurm-\$VER.tar.bz2 --define '_lto_cflags %{nil}' >> \${LOG} 2>&1
   rm slurm-\$VER.tar.bz2 >> \${LOG} 2>&1
   cd ..
   rmdir /tmp/slurm-tmp >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install python3 gcc openssl numactl hwloc lua5.3 man2html make ruby ruby-dev libmunge-dev libpam0g-dev libdbus-1-dev >> \${LOG} 2>&1
   /usr/bin/gem install fpm >> \${LOG} 2>&1
   cd
   rm -rf /tmp/slurm-tmp
   mkdir -p /tmp/slurm-tmp
   cd /tmp/slurm-tmp
   rm -rf slurm-*
   wget --no-check-certificate https://download.schedmd.com/slurm/slurm-\${VER}.tar.bz2 >> \${LOG} 2>&1
   tar jxvf slurm-\${VER}.tar.bz2 >> \${LOG} 2>&1
   cd  slurm-[0-9]*.[0-9]
   ./configure --sysconfdir=/etc/slurm --enable-pam --with-pam_dir=/lib/x86_64-linux-gnu/security/ --without-shared-libslurm >> \${LOG} 2>&1
   make >> \${LOG} 2>&1
   make contrib >> \${LOG} 2>&1
   make install >> \${LOG} 2>&1
   cd ..
;;
esac

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "Install slurm" | tee -a \${LOG}
   cd ~/rpmbuild/RPMS/x86_64
   yum -y --nogpgcheck localinstall *.rpm >> \${LOG} 2>&1
;;
esac

echo "Confirure slurm" | tee -a \${LOG}

mkdir -p /etc/slurm

cat >> /etc/slurm/slurm.conf << EOF2
SlurmctldHost=\${MASTER}
MpiDefault=none
ProctrackType=proctrack/cgroup
ReturnToService=1
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
SlurmdSpoolDir=/var/spool/slurm/slurmd
SlurmUser=slurm
StateSaveLocation=/var/spool/slurm
SwitchType=switch/none
TaskPlugin=task/affinity
SchedulerType=sched/backfill
#SelectType=select/cons_res
SelectTypeParameters=CR_Core
AccountingStorageType=accounting_storage/slurmdbd
ClusterName=cluster
JobAcctGatherType=jobacct_gather/none
PartitionName=test Nodes=ALL MaxTime=INFINITE Default=Yes State=Up
SrunPortRange=63000-64000

# For dyn. hosts:
TreeWidth=65533
MaxNodeCount=100
SelectType=select/cons_tres
EOF2
cat >> /etc/slurm/cgroup.conf << EOF2
ConstrainCores=no
ConstrainRAMSpace=no
EOF2
mkdir -p /var/spool/slurm
chown slurm:slurm /var/spool/slurm
chmod 755 /var/spool/slurm
mkdir -p /var/spool/slurm/slurmctld
chown slurm:slurm /var/spool/slurm/slurmctld
chmod 755 /var/spool/slurm/slurmctld
mkdir -p /var/spool/slurm/cluster_state
chown slurm:slurm /var/spool/slurm/cluster_state
touch /var/log/slurmctld.log
chown slurm:slurm /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
chown slurm: /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
mkdir -p /var/spool/slurm/slurmd
chown slurm:slurm /var/spool/slurm/slurmd
chmod 755 /var/spool/slurm/slurmd

case \${ID_LIKE} in
*debian*)
   cat >> /etc/systemd/system/slurmd.service <<EOF2
[Unit]
Description=Slurm node daemon
After=network.target munge.service
ConditionPathExists=/etc/slurm/slurm.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmd
ExecStart=/usr/local/sbin/slurmd -d /usr/local/sbin/slurmstepd \$SLURMD_OPTIONS
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=/var/run/slurmd.pid
KillMode=process
LimitNOFILE=51200
LimitMEMLOCK=infinity
LimitSTACK=infinity

[Install]
WantedBy=multi-user.target
EOF2
;;
esac

echo "Starting slurm" | tee -a \${LOG}
STRING=\`slurmd -C | egrep NodeName\`
scontrol create \${STRING} State=cloud >> \${LOG} 2>&1
echo \${STRING} >> /etc/slurm/slurm.conf
systemctl enable slurmd.service >> \${LOG} 2>&1
systemctl start slurmd.service >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/slurm_compute.sh
}

write_slurm_howto () {
   cat >> /tmp/slurm_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_SLURM.sh <<EOF2
#!/bin/sh

echo "Running some slurm commands:"

echo 
echo Output from: \\\"sinfo\\\"
sinfo

echo 
echo Output from: \\\"slurmd -C\\\"
slurmd -C

echo 
echo Output from: \\\"srun hostname\\\"
srun hostname

cat >> /root/my.script <<EOF
#!/bin/sh
#SBATCH --time=1
sleep 2
EOF

sbatch /root/my.script

scontrol show job
sleep 5
sacct
EOF2
chmod 755 ~/HowTo_SLURM.sh
EOF1
   chmod 755 /tmp/slurm_howto.sh
}

############################################################
######################## SLURM end #########################
############################################################

############################################################
####################### Spark start ########################
############################################################

write_spark_master () {
   cat >> /tmp/spark_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1
SHARED=\$2

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo "Argument 2 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Installing Spark" | tee -a \${LOG}

echo "Modifying LSF configuration" | tee -a \${LOG}
for script in lsf-spark-shell.sh lsf-spark-submit.sh lsf-stop-spark.sh
do
   sed -i s#"/usr/local/spark/spark-1.6.1-bin-hadoop2.6"#"/usr/local/spark/spark-3.5.1-bin-hadoop3"#g \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/bin/\${script}
done

cd /tmp
curl -LO https://dlcdn.apache.org/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz  >> \${LOG} 2>&1
mkdir -p /usr/local/spark
cd /usr/local/spark
tar xzf /tmp/spark-3.5.1-bin-hadoop3.tgz >> \${LOG} 2>&1

echo "Installing sbt" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   curl -L https://www.scala-sbt.org/sbt-rpm.repo >> /etc/yum.repos.d/sbt-rpm.repo 2>>\$0.err
   yum -y --nogpgcheck install sbt >> \${LOG} 2>&1
;;
*debian*)
   echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" >> /etc/apt/sources.list.d/sbt.list
   echo "deb https://repo.scala-sbt.org/scalasbt/debian /" >> /etc/apt/sources.list.d/sbt_old.list
   curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | apt-key add 2>>\$0.err
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install sbt >> \${LOG} 2>&1
   apt -y -qq install default-jre >> \${LOG} 2>&1
   apt -y update >> \${LOG} 2>&1
   apt -y -qq install sbt >> \${LOG} 2>&1
;;
esac

echo "Writing files" | tee -a \${LOG}

mkdir -p \${SHARED}/spark
chmod 777 \${SHARED}/spark
mkdir -p \${SHARED}/spark/src/main/scala
cat >> \${SHARED}/spark/build.sbt <<EOF2
name := "Simple Project"

version := "1.0"

scalaVersion := "2.12.17"

libraryDependencies += "org.apache.spark" %% "spark-sql" % "3.5.1"
EOF2

touch \${SHARED}/SimpleApp.log
chmod 777 \${SHARED}/SimpleApp.log
cat >> \${SHARED}/spark/src/main/scala/SimpleApp.scala <<EOF2
/* SimpleApp.scala */
import org.apache.spark.sql.SparkSession

object SimpleApp {
  def main(args: Array[String]) {
    val logFile = "\${SHARED}/SimpleApp.log" // Should be some file on your system
    val spark = SparkSession.builder.appName("Simple Application").getOrCreate()
    val logData = spark.read.textFile(logFile).cache()
    val numAs = logData.filter(line => line.contains("a")).count()
    val numBs = logData.filter(line => line.contains("b")).count()
    println(s"Lines with a: \$numAs, Lines with b: \$numBs")
    spark.stop()
  }
}
EOF2

cat >> \${SHARED}/spark/myfile.txt <<EOF2
aa
bb
cc
aa
dd
EOF2

echo "Compiling files" | tee -a \${LOG}
cd \${SHARED}/spark
sbt package >> \${LOG} 2>&1
/usr/local/spark/spark-3.5.1-bin-hadoop3/bin/spark-submit --class "SimpleApp" --master local[4] target/scala-2.12/simple-project_2.12-1.0.jar >> \${LOG} 2>&1
cp \${SHARED}/spark/target/scala-2.12/simple-project_2.12-1.0.jar \${SHARED}/spark
EOF1
   chmod 755 /tmp/spark_master.sh
}

write_spark_compute () {
   cat >> /tmp/spark_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

echo "Modifying LSF configuration" | tee -a \${LOG}
for script in lsf-spark-shell.sh lsf-spark-submit.sh lsf-stop-spark.sh
do
   sed -i s#"/usr/local/spark/spark-1.6.1-bin-hadoop2.6"#"/usr/local/spark/spark-3.5.1-bin-hadoop3"#g \${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/bin/\${script}
done

echo "Installing Spark" | tee -a \${LOG}

cd /tmp
curl -LO https://dlcdn.apache.org/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz  >> \${LOG} 2>&1
mkdir -p /usr/local/spark
cd /usr/local/spark
tar xzf /tmp/spark-3.5.1-bin-hadoop3.tgz >> \${LOG} 2>&1
chmod -R 777 /usr/local/spark

case \${ID_LIKE} in
*debian*)
   echo "Installing JRE" | tee -a \${LOG}
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install default-jre >> \${LOG} 2>&1
;;
esac
EOF1
   chmod 755 /tmp/spark_compute.sh
}

write_spark_howto () {
   cat >> /tmp/spark_howto.sh <<EOF1
#!/bin/sh

SHARED=\$1

cat >> ~/HowTo_Spark.sh <<EOF2
#!/bin/sh

echo "Submitting spark job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -n 1 -I lsf-spark-submit.sh --class "SimpleApp" \${SHARED}/spark/simple-project_2.12-1.0.jar \${SHARED}/spark/myfile.txt"
   echo
   sudo -i -u lsfadmin bsub -n 1 -I lsf-spark-submit.sh --class "SimpleApp" \${SHARED}/spark/simple-project_2.12-1.0.jar \${SHARED}/spark/myfile.txt
;;
*)
   echo "   bsub -n 1 -I lsf-spark-submit.sh --class "SimpleApp" \${SHARED}/spark/simple-project_2.12-1.0.jar \${SHARED}/spark/myfile.txt"
   echo
   bsub -n 1 -I lsf-spark-submit.sh --class "SimpleApp" \${SHARED}/spark/simple-project_2.12-1.0.jar \${SHARED}/spark/myfile.txt
;;
esac
EOF2
   chmod 755 ~/HowTo_Spark.sh
EOF1
   chmod 755 /tmp/spark_howto.sh
}

############################################################
######################## Spark end #########################
############################################################

############################################################
##################### Streamflow start #####################
############################################################

write_streamflow_master () {
   cat >> /tmp/streamflow_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

SHARED=\$1

echo | tee -a \${LOG}
echo "Argument 1 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

HOSTNAME=\`hostname -f\`
ssh-keyscan \${HOSTNAME} >> \$HOME/.ssh/known_hosts 2>/dev/null
mkdir -p \${SHARED}/streamflow
chmod -R 777 \${SHARED}/streamflow

echo "Installing packages" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install pip python-devel git coreutils >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install python3-pip git coreutils >> \${LOG} 2>&1
;;
esac

cd \${SHARED}/streamflow
echo "Clone cwl-1000genome-workflow" | tee -a \${LOG}
git clone https://github.com/alpha-unito/cwl-1000genome-workflow >> \${LOG} 2>&1
cd cwl-1000genome-workflow

case \${ID_LIKE} in
*rhel*|*fedora*)
   echo "Installing streamflow" | tee -a \${LOG}
   pip install streamflow==0.2.0.dev11 >> \${LOG} 2>&1
   echo "Add plugin streamflow-lsf" | tee -a \${LOG}
   pip install streamflow-lsf >> \${LOG} 2>&1
   echo "Checking requirements" | tee -a \${LOG}
   pip install -r requirements.txt >> \${LOG} 2>&1
;;
*debian*)
   echo "Installing streamflow" | tee -a \${LOG}
   pip3 install streamflow==0.2.0.dev11 >> \${LOG} 2>&1
   echo "Add plugin streamflow-lsf" | tee -a \${LOG}
   pip3 install streamflow-lsf >> \${LOG} 2>&1
   echo "Checking requirements" | tee -a \${LOG}
   pip3 install -r requirements.txt >> \${LOG} 2>&1
;;
esac

echo "Downloading data" | tee -a \${LOG}
#./download_data.sh 
cd /tmp
curl -Lo 1000genomes.tgz https://ibm.box.com/shared/static/21hllfsiqp5h3ftp7d7qicfmmc06pudh.tzg >> \${LOG} 2>&1
cd \${SHARED}/streamflow/cwl-1000genome-workflow
mkdir -p data
tar xzf /tmp/1000genomes.tgz >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/streamflow_master.sh
}

write_streamflow_howto () {
   cat >> /tmp/streamflow_howto.sh <<EOF1
#!/bin/sh

SHARED=\$1

cat >> ~/HowTo_Streamflow.sh <<EOF2
#!/bin/sh

DATE=\\\`date +%Y%m%d_%Hh%M\\\`
STEP="100"
TOTAL="1000"
MAX_JOBS="10"
HOSTNAME=\\\`hostname -f\\\`
ssh-keyscan \\\${HOSTNAME} >> \\\$HOME/.ssh/known_hosts 2>/dev/null

echo "Write config_\\\${DATE}.yml"
cat \${SHARED}/streamflow/cwl-1000genome-workflow/config.yml | egrep -v '(^step:|^total:)' >> \${SHARED}/streamflow/cwl-1000genome-workflow/config_\\\${DATE}.yml
cat >> \${SHARED}/streamflow/cwl-1000genome-workflow/config_\\\${DATE}.yml <<EOF3
step: \\\${STEP}
total: \\\${TOTAL}
EOF3

echo "Write streamflow_\\\${DATE}.yml"
cat >> \${SHARED}/streamflow/cwl-1000genome-workflow/streamflow_\\\${DATE}.yml <<EOF3
#!/usr/bin/env streamflow
version: v1.0
workflows:
  genome:
    type: cwl
    config:
      file: main.cwl
      settings: config_\\\${DATE}.yml
    bindings:
      - step: /
        target:
          deployment: lsf-deployment
deployments:
  ssh-deplyoment:
    type: ssh
    config:
      nodes:
        - \\\${HOSTNAME}
      sshKey: /home/lsfadmin/.ssh/id_rsa
      username: lsfadmin
  lsf-deployment:
    type: unito.lsf
    config:
      maxConcurrentJobs: \\\${MAX_JOBS}
    wraps: ssh-deplyoment
    workdir: \${SHARED}/streamflow/\\\${DATE}
EOF3

echo
echo "Executing"
echo "streamflow run streamflow_\${DATE}.yml"
cd \${SHARED}/streamflow/cwl-1000genome-workflow
/usr/local/bin/streamflow run streamflow_\\\${DATE}.yml
EOF2
   chmod 755 ~/HowTo_Streamflow.sh
EOF1
   chmod 755 /tmp/streamflow_howto.sh
}

############################################################
###################### Streamflow end ######################
############################################################

############################################################
###################### stress-ng start #####################
############################################################

write_stressng_compute () {
   cat >> /tmp/stressng_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing stress-ng" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install stress-ng >> \${LOG} 2>&1
;;
*debian*)
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install stress-ng >> \${LOG} 2>&1
;;
esac

EOF1
   chmod 755 /tmp/stressng_compute.sh
}

write_stressng_howto () {
   cat >> /tmp/stressng_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_stress-ng.sh <<EOF2
#!/bin/sh

echo "Submitting stress-ng job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -I stress-ng --cpu 8 --io 4 --vm 2 --vm-bytes 128M --fork 4 --timeout 10s"
   echo
   sudo -i -u lsfadmin bsub -I stress-ng --cpu 8 --io 4 --vm 2 --vm-bytes 128M --fork 4 --timeout 10s
;;
*)
   echo "   bsub -I stress-ng --cpu 8 --io 4 --vm 2 --vm-bytes 128M --fork 4 --timeout 10s"
   echo
   bsub -I stress-ng --cpu 8 --io 4 --vm 2 --vm-bytes 128M --fork 4 --timeout 10s
;;
esac
EOF2
   chmod 755 ~/HowTo_stress-ng.sh
EOF1
   chmod 755 /tmp/stressng_howto.sh
}

############################################################
###################### stress-ng end #######################
############################################################

############################################################
###################### Symphony start ######################
############################################################

write_symphony () {
   cat >> /tmp/symphony.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

ROLE=\$1
SYM_TOP=\$2
SYM_ENTITLEMENT_EGO=\$3
SYM_ENTITLEMENT_SYM=\$4
SYM_CLUSTER_NAME=\$5
SYM_MASTER=\$6
ROOTPWD=\$7

echo | tee -a \${LOG}
echo "Argument 1 SYM_TOP: \${SYM_TOP}" | tee -a \${LOG}
echo "Argument 2 SYM_ENTITLEMENT_EGO: \${SYM_ENTITLEMENT_EGO}" | tee -a \${LOG}
echo "Argument 3 SYM_ENTITLEMENT_SYM: \${SYM_ENTITLEMENT_SYM}" | tee -a \${LOG}
echo "Argument 4 SYM_CLUSTER_NAME: \${SYM_CLUSTER_NAME}" | tee -a \${LOG}
echo "Argument 5 SYM_MASTER: \${SYM_MASTER}" | tee -a \${LOG}
echo | tee -a \${LOG}

case \${ID_LIKE} in
*debian*)
   echo "Symphony is NOT supported on Ubuntu, exiting..." | tee -a \${LOG}
   exit
;;
esac

echo "Install some RPMs" | tee -a \${LOG}
yum -y --nogpgcheck install chkconfig libnsl >> \${LOG} 2>&1

echo "Adding user egoadmin" | tee -a \${LOG}
adduser egoadmin >> \${LOG} 2>&1
echo "\${ROOTPWD}" | passwd --stdin egoadmin >> \${LOG} 2>&1

echo "Downloading Symphony tarball from box" | tee -a \${LOG}
cd /tmp
echo "  sym-7.3.2.0_x86_64.bin" | tee -a \${LOG}
curl -Lo sym-7.3.2.0_x86_64.bin https://ibm.box.com/shared/static/iqxzvcui4zuw1h0r5gha8l2brnxb3aam.bin | tee -a \${LOG}
chmod 755 sym-7.3.2.0_x86_64.bin
export IBM_SPECTRUM_SYMPHONY_LICENSE_ACCEPT="Y"
echo "Installing Symphony" | tee -a \${LOG}
./sym-7.3.2.0_x86_64.bin --quiet --prefix \${SYM_TOP} | tee -a \${LOG}

case \${ROLE} in
master)
   echo "ego_base 4.0 () () () () \${SYM_ENTITLEMENT_EGO}" >> /tmp/sym_adv_entitlement.dat
   echo "sym_advanced_edition 7.3.2 () () () () \${SYM_ENTITLEMENT_SYM}" >> /tmp/sym_adv_entitlement.dat
   cat >> /tmp/exec.sh <<EOF2
. \${SYM_TOP}/profile.platform
egoconfig join \${SYM_MASTER} -f
egoconfig setpassword -x Admin -f
egoconfig setentitlement /tmp/sym_adv_entitlement.dat
EOF2
   chmod 755 /tmp/exec.sh
   su - egoadmin /tmp/exec.sh

   echo "export EGO_CLIENT_ADDR=\"56000-56255\"" >> \${SYM_TOP}/profile.platform
   sed -i s/"<ego:ActivitySpecification>"/"<ego:ActivitySpecification>\n      <ego:EnvironmentVariable name=\"SSM_SDK_ADDR\">31000-31255<\/ego:EnvironmentVariable>\n      <ego:EnvironmentVariable name=\"SSM_SIM_ADDR\">32000-32255<\/ego:EnvironmentVariable>"/g \${SYM_TOP}/eservice/esc/conf/services/sd.xml
   sed -i -e s/"@SMC_MASTER_LIST@"/"\${SYM_SMC_MASTER}\${DYNDNS_DOMAIN}"/g -e s/"@SMC_KD_PORT@"/"7880"/g -e s/"MANUAL"/"AUTOMATIC"/g \${SYM_TOP}/eservice/esc/conf/services/smcp.xml
   sed -i s/"MANUAL"/"AUTOMATIC"/g \${SYM_TOP}/eservice/esc/conf/services/hostfactory.xml
   sed -i s/"(linux)"/"(linux mg)"/g \${SYM_TOP}/kernel/conf/ego.cluster.\${CLUSTERNAME}
   echo "egosh user logon -u Admin -x Admin 1>/dev/null 2>/dev/null" >> \${SYM_TOP}/profile.platform
;;
compute)
   cat >> /etc/hosts <<EOF2
11.22.33.44 \${SYM_MASTER}
EOF2
   cat >> /tmp/exec.sh <<EOF2
. \${SYM_TOP}/profile.platform
egoconfig join \${SYM_MASTER} -f
EOF2
   chmod 755 /tmp/exec.sh
   su - egoadmin /tmp/exec.sh
;;
esac
. \${SYM_TOP}/profile.platform
egosetrc.sh >> \${LOG} 2>&1
ln -s \${SYM_TOP}/profile.platform /etc/profile.d/profile.platform.sh
systemctl enable ego >> \${LOG} 2>&1
systemctl start ego >> \${LOG} 2>&1
EOF1
   chmod 755 /tmp/symphony.sh
}

write_symphony_howto () {
   cat >> /tmp/symphony_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Symphony.sh <<EOF2
#!/bin/sh

DESKTOP_LINK="/root/Desktop/Symphony.desktop"
URL="https://localhost:8443"
cat >> \\\${DESKTOP_LINK} <<EOF3
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox \\\${URL}
Name=Symphony
Icon=firefox
EOF3
gio set \\\${DESKTOP_LINK} "metadata::trusted" true
chmod 755 "\\\${DESKTOP_LINK}"

. /etc/profile.d/profile.platform.sh

echo "Executing:"
echo "   egosh resource list"
echo
egosh resource list
sleep 5
echo
echo "   symping"
symping
EOF2
   chmod 755 ~/HowTo_Symphony.sh
EOF1
   chmod 755 /tmp/symphony_howto.sh
}

############################################################
####################### Symphony end #######################
############################################################

############################################################
##################### Tensorflow start #####################
############################################################








write_tensorflow_master () {
   cat >> /tmp/tensorflow_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

LSF_TOP=\$1

echo | tee -a \${LOG}
echo "Argument 1 LSF_TOP: \${LSF_TOP}" | tee -a \${LOG}
echo | tee -a \${LOG}

LSB_APPLICATIONS=\`ls \${LSF_TOP}/conf/lsbatch/*/configdir/lsb.applications\`
RET=\`egrep tensorflow \${LSB_APPLICATIONS}\`
if test "\${RET}" = ""
then
   echo "Modify LSF configuration" | tee -a \${LOG}
   cat >> \${LSB_APPLICATIONS} <<EOF2

Begin Application
NAME = tensorflow
RES_REQ = span[hosts=1]
CONTAINER = podman[image(docker.io/tensorflow/tensorflow:latest-jupyter) options(-it -p 8888:8888)]
DESCRIPTION = Octave
EXEC_DRIVER = context[user(default)] \
   starter[\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/docker-starter.py] \
   controller[\${LSF_TOP}/10.1/linux3.10-glibc2.17-x86_64/etc/docker-control.py]
End Application
EOF2
   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd\`
      if test "\${RET}" = ""
      then
         . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
EOF1
   chmod 755 /tmp/tensorflow_master.sh
}

write_tensorflow_compute () {
   cat >> /tmp/tensorflow_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}"
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Pulling image tensorflow for lsfadmin" | tee -a \${LOG}
sudo -i -u lsfadmin podman pull docker.io/tensorflow/tensorflow:latest-jupyter >> \${LOG} 2>&1

EOF1
   chmod 755 /tmp/tensorflow_compute.sh
}

write_tensorflow_howto () {
   cat >> /tmp/tensorflow_howto.sh <<EOF1
#!/bin/sh

cat >> ~/HowTo_Tensorflow.sh <<EOF2
#!/bin/sh



echo "Submitting tensorflow job:"
USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -app tensorflow -Ip /bin/bash"
   echo
   sudo -i -u lsfadmin bsub -app tensorflow -Ip /bin/bash
;;
*)
   echo "   bsub -app tensorflow -Ip /bin/bash"
   echo
   bsub -app tensorflow -Ip /bin/bash
;;
esac
EOF2
   chmod 755 ~/HowTo_Tensorflow.sh
EOF1
   chmod 755 /tmp/tensorflow_howto.sh
}













############################################################
###################### Tensorflow end ######################
############################################################

############################################################
######################## Toil start ########################
############################################################

write_toil_master () {
   cat >> /tmp/toil_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing Toil" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install pip python3-devel >> \${LOG} 2>&1
   pip install toil[cwl] >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install python3-pip >> \${LOG} 2>&1
   pip3 install toil[cwl] >> \${LOG} 2>&1
;;
esac

RET=\`egrep LSF_ROOT_USER \${LSF_TOP}/conf/lsf.conf\`
if test "\${RET}" = ""
then
   echo "LSF_ROOT_USER=Y" >> \${LSF_TOP}/conf/lsf.conf

   if test "\${REGION}" = "onprem"
   then
      echo "Restarting LSF" | tee -a \${LOG}
      RET=\`systemctl status lsfd 2>/dev/null\`
      if test "\${RET}" = ""
      then
         . \${LSF_TOP}/conf/profile.lsf
         lsf_daemons restart
      else
         systemctl restart lsfd
      fi
   fi
fi
EOF1
   chmod 755 /tmp/toil_master.sh
}

write_toil_compute () {
   cat >> /tmp/toil_compute.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

echo "Installing Toil" | tee -a \${LOG}

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install pip python3-devel >> \${LOG} 2>&1
   pip install toil[cwl] >> \${LOG} 2>&1
;;
*debian*)
   apt -y update >> \${LOG} 2>&1
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install python3-pip >> \${LOG} 2>&1
   pip3 install toil[cwl] >> \${LOG} 2>&1
;;
esac
EOF1
   chmod 755 /tmp/toil_compute.sh
}

write_toil_howto () {
   cat >> /tmp/toil_howto.sh <<EOF1
#!/bin/sh

SHARED=\$1

cat >> ~/HowTo_Toil.sh <<EOF2
#!/bin/sh

echo "Writing \${SHARED}/1st-tool.cwl" | tee -a \${LOG}
cat >> \${SHARED}/1st-tool.cwl <<EOF3
#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
baseCommand: echo
inputs:
  message:
    type: string
    inputBinding:
      position: 1
outputs: []
EOF3

echo "Writing \${SHARED}/echo-job.yml" | tee -a \${LOG}
cat >> \${SHARED}/echo-job.yml <<EOF3
message: Hello world!
EOF3

echo "Executing:"
echo "/usr/local/bin/toil-cwl-runner --batchSystem=lsf --disableCaching --jobStore  \${SHARED}/\\\$\\\$ --defaultMemory 100M --logDebug \${SHARED}/1st-tool.cwl \${SHARED}/echo-job.yml"
/usr/local/bin/toil-cwl-runner --batchSystem=lsf --disableCaching --jobStore  \${SHARED}/\\\$\\\$ --defaultMemory 100M --logDebug \${SHARED}/1st-tool.cwl \${SHARED}/echo-job.yml
EOF2
   chmod 755 ~/HowTo_Toil.sh
EOF1
   chmod 755 /tmp/toil_howto.sh
}

############################################################
######################### Toil end #########################
############################################################

############################################################
##################### Veloxchem start ######################
############################################################

write_veloxchem_master () {
   cat >> /tmp/veloxchem_master.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

SHARED=\$1

echo "Installing VeloxChem" | tee -a \${LOG}

echo | tee -a \${LOG}
echo "Argument 1 SHARED: \${SHARED}" | tee -a \${LOG}
echo | tee -a \${LOG}

mkdir -p ${SHARED}/veloxchem

# Based upon:
# https://veloxchem.org/docs/installation.html

case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install environment-modules >> \${LOG} 2>&1
   . /etc/alternatives/modules.sh
;;
*debian*)
   systemctl disable --now unattended-upgrades
   PID=\`ps auxww | egrep unattended-upgrade | egrep -v grep | awk '{print \$2}'\`
   if test "\${PID}" != ""
   then
      kill -9 \${PID}
      sleep 5
   fi
   export DEBIAN_FRONTEND=noninteractive
   apt -y -qq install environment-modules >> \${LOG} 2>&1
   echo ". /usr/share/modules/init/bash" >> /root/.bashrc
   #. /usr/share/modules/init/bash
;;
esac

echo "Install Math Kernel Library" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y --nogpgcheck install yum-utils >> \${LOG} 2>&1
   yum-config-manager --add-repo https://yum.repos.intel.com/mkl/setup/intel-mkl.repo >> \${LOG} 2>&1
   rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB >> \${LOG} 2>&1
   yum -y --nogpgcheck install intel-mkl-64bit >> \${LOG} 2>&1
;;
*debian*)
   curl -LO https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB >> \${LOG} 2>&1
   apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB >> \${LOG} 2>&1
   wget https://apt.repos.intel.com/setup/intelproducts.list -O /etc/apt/sources.list.d/intelproducts.list >> \${LOG} 2>&1
   sh -c 'echo deb https://apt.repos.intel.com/mkl all main >> /etc/apt/sources.list.d/intel-mkl.list'
   apt-key adv --keyserver keyserver.ubuntu.com --recv-keys BAC6F0C353D04109 >> \${LOG} 2>&1
   apt-get -y update >> \${LOG} 2>&1
   apt-get -y install intel-mkl-64bit-2019.1-053 >> \${LOG} 2>&1
;;
esac
echo | tee -a \${LOG}

echo "Install MPI and Python" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   yum -y install cmake git gcc gcc-g++ mpich mpich-devel python3 python3-devel python3-pip >> \${LOG} 2>&1
;;
*debian*)
   apt-get -y -qq install git mpich python3 cmake python3-dev python3-pip python3-venv >> \${LOG} 2>&1
;;
esac
echo | tee -a \${LOG}

echo "Create and activate a virtual enviroment" | tee -a \${LOG}
python3 -m venv vlxenv >> \${LOG} 2>&1
source vlxenv/bin/activate 
python3 -m pip install --upgrade pip setuptools wheel >> \${LOG} 2>&1
python3 -m pip install numpy mpi4py h5py >> \${LOG} 2>&1
python3 -m pip install cmake pybind11-global scikit-build >> \${LOG} 2>&1
echo | tee -a \${LOG}

echo "Install Libxc" | tee -a \${LOG}
cd /tmp
curl -LO https://gitlab.com/libxc/libxc/-/archive/6.0.0/libxc-6.0.0.tar.bz2 >> \${LOG} 2>&1
tar xf libxc-6.0.0.tar.bz2 >> \${LOG} 2>&1
cd libxc-6.0.0
cmake -H. -Bobjdir >> \${LOG} 2>&1
cd objdir && make >> \${LOG} 2>&1
make install >> \${LOG} 2>&1
echo | tee -a \${LOG}

echo "Install VeloxChem" | tee -a \${LOG}
case \${ID_LIKE} in
*rhel*|*fedora*)
   module load mpi/mpich-x86_64 >> \${LOG} 2>&1
;;
esac

cd ${SHARED}/veloxchem
source /opt/intel/mkl/bin/mklvars.sh intel64
export SKBUILD_CONFIGURE_OPTIONS="-DVLX_LA_VENDOR=MKL -DCMAKE_CXX_COMPILER=mpicxx"
export CMAKE_PREFIX_PATH=/path/to/your/libxc/:\${CMAKE_PREFIX_PATH}
export CPATH="/opt/intel/compilers_and_libraries_2019.1.144/linux/mkl/include"
export PKG_CONFIG_PATH="/opt/intel/compilers_and_libraries_2019.1.144/linux/mkl/bin/pkgconfig"
export PATH="/root/vlxenv/bin:\${PATH}"
export MKLROOT=/opt/intel/compilers_and_libraries_2019.1.144/linux/mkl
python3 -m pip install git+https://gitlab.com/veloxchem/veloxchem >> \${LOG} 2>&1
echo | tee -a \${LOG}

cp -r /root/vlxenv ${SHARED}/veloxchem

cat >> ${SHARED}/veloxchem/water.inp <<EOF2
@jobs
task: scf
@end

@method settings
xcfun: b3lyp
basis: def2-svp
@end

@molecule
charge: 0
multiplicity: 1
xyz:
O  0.00000  0.00000  0.00000
H  0.00000  0.00000  1.79524
H  1.69319  0.00000 -0.59904
@end
EOF2
chmod -R 777 ${SHARED}/veloxchem
sed -i s#/root#/shared/veloxchem#g /shared/veloxchem/vlxenv/bin/vlx
EOF1
   chmod 755 /tmp/veloxchem_master.sh
}

write_veloxchem_howto () {
   cat >> /tmp/veloxchem_howto.sh <<EOF1
#!/bin/sh

SHARED=\$1

cat >> ~/HowTo_VeloxChem.sh <<EOF2
#!/bin/sh

echo "Run example 'water'"


USER=\\\`whoami\\\`
case \\\${USER} in
root)
   echo "   sudo -i -u lsfadmin bsub -I \"export LD_LIBRARY_PATH=\"/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl:/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl/lib/intel64_lin\" ; ${SHARED}/veloxchem/vlxenv/bin/vlx ${SHARED}/veloxchem/water.inp\""
   echo
   sudo -i -u lsfadmin bsub -I "export LD_LIBRARY_PATH=\"/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl:/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl/lib/intel64_lin\" ; ${SHARED}/veloxchem/vlxenv/bin/vlx ${SHARED}/veloxchem/water.inp"
;;
*)
   echo "   bsub -I \"export LD_LIBRARY_PATH=\"/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl:/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl/lib/intel64_lin\" ; ${SHARED}/veloxchem/vlxenv/bin/vlx ${SHARED}/veloxchem/water.inp\""
   echo
   bsub -I "export LD_LIBRARY_PATH=\"/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl:/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl/lib/intel64_lin\" ; ${SHARED}/veloxchem/vlxenv/bin/vlx ${SHARED}/veloxchem/water.inp"
;;
esac
EOF2
   chmod 755 ~/HowTo_VeloxChem.sh
EOF1
   chmod 755 /tmp/veloxchem_howto.sh
}

############################################################
###################### Veloxchem end #######################
############################################################

############################################################
##################### Yellowdog start ######################
############################################################

write_yellowdog () {
   cat >> /tmp/yellowdog.sh <<EOF1
#!/bin/sh

. /etc/os-release
. /var/environment.sh

HOSTNAME=\`hostname\`
echo "Executing \$0 on \${HOSTNAME}" | tee -a \${LOG}
NAME=\`basename \$0 | sed s/".sh"//g\`
LOG="/var/log/\${NAME}.log"

. /var/environment.sh

echo "Installing Yellowdog" | tee -a \${LOG}

MYIP_INT=\`ifconfig | fgrep "inet " | awk '{print \$2}' | head -1\`
HOSTNAME=\`hostname -s\`
cd /tmp
echo "Downloading yd-agent-installer.sh from box" | tee -a \${LOG}
echo "   yd-agent-installer.sh" | tee -a \${LOG}
curl -Lo yd-agent-installer.sh https://ibm.box.com/shared/static/y08whhue834rfmi68epx82kf1pkgol2x.sh >> \${LOG} 2>&1
chmod 755 yd-agent-installer.sh
export YD_CONFIGURED_WP="TRUE"
export YD_REGION="\${REGION}"
echo "   YD_REGION set to \${YD_REGION}" | tee -a \${LOG}
./yd-agent-installer.sh >> \${LOG} 2>&1
sed -i s/"privateIpAddress: \"\""/"privateIpAddress: \"\${MYIP_INT}\""/g /opt/yellowdog/agent/application.yaml
case "\${HOSTNAME}" in
*master*)
   sed -i s/"instanceType: \"\""/"instanceType: \"master\""/g /opt/yellowdog/agent/application.yaml
;;
*)
   sed -i s/"instanceType: \"\""/"instanceType: \"compute\""/g /opt/yellowdog/agent/application.yaml
;;
esac
if test "\${REGION}" != "onprem"
then
   # Remove the preliminary config when in the cloud
   echo "Removing /opt/yellowdog/agent/application.yaml" | tee -a \${LOG}
   rm -rf /opt/yellowdog/agent/application.yaml
fi
EOF1
   chmod 755 /tmp/yellowdog.sh
}
############################################################
###################### Yellowdog end #######################
############################################################
