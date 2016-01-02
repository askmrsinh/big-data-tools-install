#!/usr/bin/env bash

# https://github.com/user501254/BD_STTP_2016
#
# InstallHadoop.sh
# Bash Script for rudimentary Hadoop Installation (Single-Node Cluster)
#
# To run:
#  open terminal,
#  change directory to this script's location,
#    $ cd <link to InstallHadoop.sh parent directory>
#  give execute permission to the script,
#    $ sudo chmod +x InstallHadoop.sh
#  then execute the script,
#    $ ./InstallHadoop.sh
#
#
# Copyright (C) 2016 Ashesh Kumar Singh <user501254@gmail.com>
#
# This script may be modified and distributed under the terms
# of the MIT license. See the LICENSE file for details.
#


# Make sure that the script is not being run as root
if [[ "$EUID" -eq 0 ]]; then
  echo -e "\e[31m
  You are running this script as root which can cause problems.
  Please run this script as a normal user. See script file.\n
  Exiting.
  \e[0m"
  exit
else
  echo -e "\e[34m
  This will install the latest version of Hadoop on your system.\n
  Make sure that you have the following before continuing:
    - working internet connection (optional)
        for downloading installation files if
        not found in the parent directory 
        ie. $PWD
    - fairly up to date system
    - enough free disk space
  I recommend that you also go through the script file once.
  \e[0m"
  while true
  do
    read -r -p 'Do you wish to continue (yes/no)?' choice
    case "$choice" in
      [Nn]* ) echo 'Exiting.'; exit;;
      [Yy]* ) echo ''; break;;
      * ) echo 'Response not valid, try again.';;
    esac
  done
fi

set -eu
set -o pipefail



clear
echo -e "\e[32mSTEP (1 of 6): Installing Java, OpenSSH, rsync\e[0m"
echo -e "\e[32m##############################################\n\e[0m"
sleep 2s

if [ -f /etc/redhat-release ]; then
  sudo yum install -y java-*-openjdk-devel openssh rsync
elif [ -f /etc/debian_version ]; then
  sudo apt-get install -y default-jdk openssh-server rsync
else
  lsb_release -si
  echo "\e[31mCan't use yum or apt-get, check installation script.\n\e[0m"
  exit
fi

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mSTEP  (2 of 6): Setting up SSH keys\e[0m"
echo -e "\e[32m###################################\n\e[0m"
sleep 2s

echo -e  'y\n' | ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
sudo systemctl restart sshd.service || sudo service ssh restart
cat << EOT >> ~/.ssh/config
Host localhost
   StrictHostKeyChecking no
Host 0.0.0.0
   StrictHostKeyChecking no
EOT

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mSTEP  (3 of 6): Downloading and Extracting Hadoop archive\e[0m"
echo -e "\e[32m#########################################################\n\e[0m"
sleep 2s

FILE=$(wget "http://www.eu.apache.org/dist/hadoop/common/stable/" -O - | grep -Po "hadoop-[0-9].[0-9].[0-9].tar.gz" | head -n 1)
URL=http://www.eu.apache.org/dist/hadoop/common/stable/$FILE

if [[ ! -f "$FILE" ]]; then
  echo -e "\e[34mDownloading file \`$FILE'; this may take time.\e[0m"
  wget -c "$URL" -O "$FILE"
  DEL_FILE=true
else
  echo -e "\e[34mFile \`$FILE' already there; not retrieving.\e[0m"
  wget -c "$URL.mds" -O - | sed '7,$ d' | tr -d " \t\n\r" | tr ":" " " | awk '{t=$1;$1=$NF;$NF=t}1' | awk '$1=$1' OFS="  " | cut -c 5- | md5sum -c
  DEL_FILE=false
fi

echo -e "\e[34mExtracting file \`$FILE'; this may take a few minutes.\e[0m"
sudo tar xfz "$FILE" -C /usr/local

if [[ "$DEL_FILE" == "true" ]]; then
  echo -e "\e[34mDeleting file \`$FILE'; to save storage space.\e[0m"
  rm -rf $FILE
fi

sudo mv /usr/local/hadoop-*/ /usr/local/hadoop
CURRENT=$USER
sudo chown -R $CURRENT:$CURRENT /usr/local/hadoop
ls -las /usr/local

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mSTEP  (4 of 6): Editing Configuration Files\e[0m"
echo -e "\e[32m###########################################\n\e[0m"

set -x
sudo update-alternatives --auto java
cp ~/.bashrc ~/.bashrc.bak
cat << 'EOT' >> ~/.bashrc
#SET JDK
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:jre/bin/java::")
#HADOOP VARIABLES START
export HADOOP_HOME=/usr/local/hadoop
export PATH=$PATH:$HADOOP_HOME/bin
export PATH=$PATH:$HADOOP_HOME/sbin
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib"
export HADOOP_CLASSPATH=${JAVA_HOME}/lib/tools.jar
#HADOOP VARIABLES END
EOT
source ~/.bashrc || true

java -version
javac -version

sed -i.bak -e 's/export JAVA_HOME=${JAVA_HOME}/export JAVA_HOME=$(readlink -f \/usr\/bin\/java | sed "s:jre\/bin\/java::")/g' /usr/local/hadoop/etc/hadoop/hadoop-env.sh

sed -n -i.bak '/<configuration>/q;p'  /usr/local/hadoop/etc/hadoop/core-site.xml
cat << EOT >> /usr/local/hadoop/etc/hadoop/core-site.xml
<configuration>
  <property>
     <name>fs.default.name</name>
     <value>hdfs://localhost:9000</value>
  </property>
</configuration>
EOT

sed -n -i.bak '/<configuration>/q;p' /usr/local/hadoop/etc/hadoop/yarn-site.xml
cat << EOT >> /usr/local/hadoop/etc/hadoop/yarn-site.xml
<configuration>
  <property>
     <name>yarn.nodemanager.aux-services</name>
     <value>mapreduce_shuffle</value>
  </property>
  <property>
     <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
     <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
</configuration>
EOT

cp /usr/local/hadoop/etc/hadoop/mapred-site.xml.template /usr/local/hadoop/etc/hadoop/mapred-site.xml
sed -n -i.bak '/<configuration>/q;p'  /usr/local/hadoop/etc/hadoop/mapred-site.xml
cat << EOT >> /usr/local/hadoop/etc/hadoop/mapred-site.xml
<configuration>
  <property>
     <name>mapreduce.framework.name</name>
     <value>yarn</value>
  </property>
</configuration>
EOT

mkdir -p /home/$USER/hadoop_store/hdfs/namenode
mkdir -p /home/$USER/hadoop_store/hdfs/datanode
sed -n -i.bak '/<configuration>/q;p'  /usr/local/hadoop/etc/hadoop/hdfs-site.xml
cat << EOT >> /usr/local/hadoop/etc/hadoop/hdfs-site.xml
<configuration>
  <property>
     <name>dfs.replication</name>
     <value>1</value>
  </property>
  <property>
     <name>dfs.namenode.name.dir</name>
     <value>file:/home/$USER/hadoop_store/hdfs/namenode</value>
  </property>
  <property>
     <name>dfs.datanode.data.dir</name>
     <value>file:/home/$USER/hadoop_store/hdfs/datanode</value>
  </property>
</configuration>
EOT
set +x

sleep 2s
echo -e "\n\n"



clear
echo -e "\e[32mSTEP  (5 of 6): Formatting HDFS (namenode directory)\e[0m"
echo -e "\e[32m####################################################\n\e[0m"
sleep 2s

/usr/local/hadoop/bin/hdfs namenode -format

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mSTEP  (6 of 6): Strating Hadoop daemons\e[0m"
echo -e "\e[32m#######################################\n\e[0m"
sleep 2s

/usr/local/hadoop/sbin/start-dfs.sh
/usr/local/hadoop/sbin/start-yarn.sh

sleep 1s
echo -e "\n\n"



clear
jps
google-chrome http://$HOSTNAME:50070 || firefox http://$HOSTNAME:50070 || midori http://$HOSTNAME:50070 || true
echo -e "\n\n"



clear
echo -e "\e[32m
Hadoop installation was successful!
Open a new terminal and execute:
  $ hadoop version
\e[0m"



#echo -e "Stopping Hadoop daemons\n"
#/usr/local/hadoop/sbin/stop-dfs.sh
#/usr/local/hadoop/sbin/stop-yarn.sh



# Online Tutorial
# https://youtu.be/gWkbPVNER5k
