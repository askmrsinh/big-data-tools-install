#!/usr/bin/env bash

# https://github.com/user501254/BD_STTP_2016
#
# InstallHBase.sh
# Bash Script for rudimentary HBase Installation (Standalone mode)
#
# To run:
#  open terminal,
#  change directory to this script's location,
#    $ cd <link to InstallHBase.sh parent directory>
#  give execute permission to the script,
#    $ sudo chmod +x InstallHBase.sh
#  then execute the script,
#    $ ./InstallHBase.sh
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
  This will install the latest version of HBase on your system.\n
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
echo -e "\e[32mInstalling Java\e[0m"
echo -e "\e[32m###############\n\e[0m"
sleep 2

if [ -f /etc/redhat-release ]; then
  sudo yum clean expire-cache
  sudo yum install -y java-*-openjdk-devel
elif [ -f /etc/debian_version ]; then
  sudo apt-get update
  sudo apt-get install -y default-jdk
else
  lsb_release -si
  echo "\e[31mCan't use yum or apt-get, check installation script.\n\e[0m"
  exit
fi

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mDownloading and Extracting HBase archive\e[0m"
echo -e "\e[32m########################################\n\e[0m"
sleep 2s

FILE=$(wget "http://www.us.apache.org/dist/hbase/stable/" -O - | grep -Po "hbase-[0-9].[0-9].[0-9]-bin.tar.gz" | head -n 1)
URL=http://www.us.apache.org/dist/hbase/stable/$FILE

if [[ ! -f "$FILE" ]]; then
  echo -e "\e[34mDownloading file \`$FILE'; this may take a few minutes.\e[0m"
  wget -c "$URL" -O "$FILE"
  DEL_FILE=true
else
  echo -e "\e[34mFile \`$FILE' already there; not retrieving.\e[0m"
  wget -c "$URL.mds" -O - | sed '3,$ d' | tr -d " \t\n\r" | tr ":" " " | awk '{t=$1;$1=$NF;$NF=t}1' | awk '$1=$1' OFS="  " | cut -c 5- | md5sum -c
  DEL_FILE=false
fi

if [[ -d /usr/local/hbase ]]; then
  echo -e "\e[34m
  Removing previous HBase installation directory;
    \`/usr/local/hbase'
  \e[0m"
  /usr/local/hbase/bin/stop-hbase.sh &>/dev/null || true
  sudo rm -rf /usr/local/hbase
fi

if [[ -d ~/hadoop_store ]]; then
  echo -e "\e[34m
  Removing previous HBase root directory;
    \`~/hadoop_store/hbase'
  \e[0m"
  rm -rf ~/hadoop_store/hbase
fi

echo -e "\e[34mExtracting file \`$FILE'; this may take a few minutes.\e[0m"
sudo tar xfz "$FILE" -C /usr/local

if [[ "$DEL_FILE" == "true" ]]; then
  echo -e "\e[34mDeleting file \`$FILE'; to save storage space.\e[0m"
  rm -rf $FILE
fi

sudo mv /usr/local/hbase-*/ /usr/local/hbase
sudo chown -R $USER:$USER /usr/local/hbase

ls -las /usr/local

sleep 1s
echo -e "\n\n"


set -xv
sudo update-alternatives --auto java
java -version
javac -version
cp ~/.bashrc ~/.bashrc.bak
sed -i -e '/#HBase VARIABLES START/,+3d' ~/.bashrc
cat << 'EOT' >> ~/.bashrc
#HBase VARIABLES START
export HBASE_HOME=/usr/local/hbase
export PATH=$PATH:$HBASE_HOME/bin
#HBase VARIABLES END
EOT

sed -i.bak -e 's/# export JAVA_HOME=.*/export JAVA_HOME=$(readlink -f \/usr\/bin\/java | sed "s:jre\/bin\/java::")/g' /usr/local/hbase/conf/hbase-env.sh

sudo sed -n -i.bak '/<configuration>/q;p' /usr/local/hbase/conf/hbase-site.xml
sudo cat << EOT >> /usr/local/hbase/conf/hbase-site.xml
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file:/home/$USER/hadoop_store/hbase</value>
  </property>
</configuration>
EOT
set +xv


/usr/local/hbase/bin/start-hbase.sh



clear
jps
#google-chrome http://$HOSTNAME:16010 || firefox http://$HOSTNAME:16010 || midori http://$HOSTNAME:16010 || true
echo -e "\n\n"

set +euo pipefail



source ~/.bashrc &>/dev/null



clear
echo -e "\e[32m
Hbase installation was successful!
Open a new terminal and execute:
  $ hbase
\e[0m"



#echo -e "Stopping HBase daemons\n"
#/usr/local/hbase/bin/stop-hbase.sh
