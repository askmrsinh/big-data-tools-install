#!/usr/bin/env bash

# https://github.com/user501254/BD_STTP_2016
#
# InstallSpark.sh
# Bash Script for rudimentary Spark Installation
#
# To run:
#  open terminal,
#  change directory to this script's location,
#    $ cd <link to InstallSpark.sh parent directory>
#  give execute permission to the script,
#    $ sudo chmod +x InstallSpark.sh
#  then execute the script,
#    $ ./InstallSpark.sh
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
  This will install the latest version of Spark on your system.\n
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
echo -e "\e[32mSTEP (1 of 6): Installing Java, Scala, Python, sbt\e[0m"
echo -e "\e[32m##############################################\n\e[0m"
sleep 2s

if [ -f /etc/redhat-release ]; then
  sudo yum clean expire-cache
  sudo yum install -y java-*-openjdk-devel scala python sbt
elif [ -f /etc/debian_version ]; then
  sudo apt-get update
  sudo apt-get install -y default-jdk scala python sbt
else
  lsb_release -si
  echo "\e[31mCan't use yum or apt-get, check installation script.\n\e[0m"
  exit
fi

sleep 1s
echo -e "\n\n"



clear
echo -e "\e[32mDownloading and Extracting Spark archive\e[0m"
echo -e "\e[32m########################################\n\e[0m"
sleep 2s

VERSION=$(wget http://spark.apache.org/downloads.html -O - | grep -Po "Spark [0-9.]{5}" | head -n 1 | grep -Po "[0-9.]{5}")
FILE=spark-$VERSION-bin-without-hadoop.tgz
URL=http://www.us.apache.org/dist/spark/spark-$VERSION/$FILE

if [[ ! -f "$FILE" ]]; then
  echo -e "\e[34mDownloading file \`$FILE'; this may take time.\e[0m"
  wget -c "$URL" -O "$FILE"
  DEL_FILE=true
else
  echo -e "\e[34mFile \`$FILE' already there; not retrieving.\e[0m"
  wget -c "$URL.md5" -O - | sed '3,$ d' | tr -d " \t\n\r" | tr ":" " " | awk '{t=$1;$1=$NF;$NF=t}1' | awk '$1=$1' OFS="  " | md5sum -c
  DEL_FILE=false
fi

echo -e "\e[34mExtracting file \`$FILE'; this may take a few minute.\e[0m"
sudo tar xfz "$FILE" -C /usr/local

if [[ "$DEL_FILE" == "true" ]]; then
  echo -e "\e[34mDeleting file \`$FILE'; to save storage space.\e[0m"
  rm -rf $FILE
fi

sudo mv /usr/local/spark-*/ /usr/local/spark
CURRENT=$USER
sudo chown -R $CURRENT:$CURRENT /usr/local/spark
ls -las /usr/local

sleep 1s
echo -e "\n\n"


set -x
cat << 'EOT' >> ~/.bashrc
#SPARK VARIABLES START
export SPARK_HOME=/usr/local/spark
export PATH=$PATH:$SPARK_HOME/bin
#SPARK VARIABLES END
EOT

cp /usr/local/spark/conf/spark-env.sh.template /usr/local/spark/conf/spark-env.sh
cat << EOT >> /usr/local/spark/conf/spark-env.sh
export SPARK_DIST_CLASSPATH=$(/usr/local/hadoop/bin/hadoop classpath)
export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop
EOT
set +x



source ~/.bashrc &>/dev/null

clear
echo -e "\e[32m
Spark installation was successful!
Open a new terminal and execute:
  $ spark-shell -help
\e[0m"



#echo -e "Show Spark shell help\n"
#/usr/local/spark/bin/spark-shell -help
