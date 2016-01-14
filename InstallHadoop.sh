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
    - working internet connection
        for downloading any required packages and 
        also the latest stable Hadoop binary if
        not found in the parent directory
        ie. $PWD
    - fairly up to date system
    - enough free disk space
  I recommend that you also go through the script file once.
  \e[0m"
  while true
  do
    read -r -p 'Do you wish to continue (yes/no)? ' choice
    case "$choice" in
      [Nn]* ) echo 'Exiting.'; exit;;
      [Yy]* ) echo ''; break;;
      * ) echo 'Response not valid, try again.';;
    esac
  done
fi

set -euo pipefail



clear
echo -e "\e[32mSTEP (1 of 6): Installing Java, OpenSSH, rsync\e[0m"
echo -e "\e[32m##############################################\n\e[0m"
sleep 2s

if [ -f /etc/redhat-release ]; then
  sudo yum clean expire-cache
  sudo yum install -y java-*-openjdk-devel openssh rsync
elif [ -f /etc/debian_version ]; then
  sudo apt-get update
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

if [[ -d ~/.ssh ]]; then
  echo -e "\e[34mBacking up \`~/.ssh' folder contents to \`~/.ssh.old'.\e[0m"
  mkdir -p ~/.ssh.old
  sudo mv --backup=t ~/.ssh/* ~/.ssh.old 2>/dev/null || true
else
  mkdir ~/.ssh
fi

sudo chown $USER:$USER ~/.ssh
chmod 700 ~/.ssh

touch ~/.ssh/known_hosts

echo -e  'y\n' | ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
sudo systemctl restart sshd.service || sudo service ssh restart
cat << EOT >> ~/.ssh/config
Host localhost
   StrictHostKeyChecking no
Host 0.0.0.0
   StrictHostKeyChecking no
EOT

chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/known_hosts

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mSTEP  (3 of 6): Downloading and Extracting Hadoop archive\e[0m"
echo -e "\e[32m#########################################################\n\e[0m"
sleep 2s

FILE=$(wget "http://www.eu.apache.org/dist/hadoop/common/stable/" -O - | grep -Po "hadoop-[0-9].[0-9].[0-9].tar.gz" | head -n 1)
URL=http://www.eu.apache.org/dist/hadoop/common/stable/$FILE

if [[ ! -f "$FILE" ]]; then
  echo -e "\e[34mDownloading file \`$FILE'; this may take a few minutes.\e[0m"
  wget -c "$URL" -O "$FILE"
  DEL_FILE=true
else
  echo -e "\e[34mFile \`$FILE' already there; not retrieving.\e[0m"
  wget -c "$URL.mds" -O - | sed '7,$ d' | tr -d " \t\n\r" | tr ":" " " | awk '{t=$1;$1=$NF;$NF=t}1' | awk '$1=$1' OFS="  " | cut -c 5- | md5sum -c
  DEL_FILE=false
fi

if [[ -d /usr/local/hadoop ]]; then
  echo -e "\e[34m
  Removing previous Hadoop installation directory;
    \`/usr/local/hadoop'
  \e[0m"
  /usr/local/hadoop/sbin/stop-dfs.sh &>/dev/null || true
  /usr/local/hadoop/sbin/stop-yarn.sh &>/dev/null || true
  sudo rm -rf /usr/local/hadoop
fi

if [[ -d ~/hadoop_store ]]; then
  echo -e "\e[34m
  Removing previous Hadoop distributed file system directories;
    \`~/hadoop_store/hdfs/namenode'
    \`~/hadoop_store/hdfs/namenode'
  \e[0m"
  rm -rf ~/hadoop_store/hdfs/namenode
  rm -rf ~/hadoop_store/hdfs/datanode
  sudo rm -rf /tmp/hadoop-$USER
fi

echo -e "\e[34mExtracting file \`$FILE'; this may take a few minutes.\e[0m"
sudo tar xfz "$FILE" -C /usr/local

if [[ "$DEL_FILE" == "true" ]]; then
  echo -e "\e[34mDeleting file \`$FILE'; to save storage space.\e[0m"
  rm -rf $FILE
fi

sudo mv /usr/local/hadoop-*/ /usr/local/hadoop
sudo chown -R $USER:$USER /usr/local/hadoop

ls -las /usr/local

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mSTEP  (4 of 6): Editing Configuration Files\e[0m"
echo -e "\e[32m###########################################\n\e[0m"

set -xv
sudo update-alternatives --auto java
java -version
javac -version
cp ~/.bashrc ~/.bashrc.bak
sed -i -e '/#HADOOP VARIABLES START/,+11d' ~/.bashrc
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

sed -i.bak -e 's/export JAVA_HOME=${JAVA_HOME}/export JAVA_HOME=$(readlink -f \/usr\/bin\/java | sed "s:jre\/bin\/java::")/g' /usr/local/hadoop/etc/hadoop/hadoop-env.sh

sed -n -i.bak '/<configuration>/q;p'  /usr/local/hadoop/etc/hadoop/core-site.xml
cat << EOT >> /usr/local/hadoop/etc/hadoop/core-site.xml
<configuration>
  <property>
     <name>fs.defaultFS</name>
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

mkdir -p ~/hadoop_store/hdfs/namenode
mkdir -p ~/hadoop_store/hdfs/datanode
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
set +xv

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
#google-chrome http://$HOSTNAME:50070 || firefox http://$HOSTNAME:50070 || midori http://$HOSTNAME:50070 || true
echo -e "\n\n"

set +euo pipefail



source ~/.bashrc &>/dev/null

clear
echo -e "\e[32m
Hadoop installation was successful!
Open a new terminal and execute:
  $ hadoop

Watch step-by-step video on YouTube.
  https://youtu.be/gWkbPVNER5k
\e[0m"



#echo -e "Stopping Hadoop daemons\n"
#/usr/local/hadoop/sbin/stop-dfs.sh
#/usr/local/hadoop/sbin/stop-yarn.sh
