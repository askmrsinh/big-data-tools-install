---
layout: page
title: Hadoop Single-Node Cluster Installation Guide
---

##Prerequisites

You can install Hadoop in a *Single-Node Cluster* or *Pseudo-Distributed Mode* for testing purpose on any UNIX like system running on either a physical machine or a Virtual Machine.

I am assuming that you already have your operating system prepaired for this. However if you don't have a working copy of a compatible operating system already installed, you can see [this link](http://askubuntu.com/questions/6328/how-do-i-install-ubuntu) for help.  

This brief tutorial will focus only on RedHat (like Fedora, CentOS) and Debian (like Ubuntu) distributions but the steps remain similar on other OSs.  
If you face any issues try steps mentioned in the Troubleshoothing section.

If the manual installation process is not working for you, have a look at this [YouTube video](https://youtu.be/gWkbPVNER5k) or simply use the automated [installation script](https://github.com/user501254/BD_STTP_2016/blob/master/InstallHadoop.sh).

##STEP 1: Installing Java, OpenSSH, rsync  
We need to install certain dependencies before installing Hadoop.  
This includes Java, OpenSSH and rsync.  

On Redhat like systems use:

    sudo yum clean expire-cache && sudo yum install -y java-*-openjdk-devel openssh rsync

On Debian like systems use:

    sudo apt-get update && sudo apt-get install -y default-jdk openssh-server rsync


##STEP 2: Setting up SSH keys  

Genrate passwordless RSA public & private keys, you will be required to answer a prompt by hitting enter to keep the default file location of the keys:

    ssh-keygen -t rsa -P ''

Add the newly created key to the list of authorized keys:

    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys


##STEP 3: Downloading and Extracting Hadoop archive  
You can download the latest stable release of Hadoop binary named *`hadoop-x.y.z.tar.gz`* from [`http://www.eu.apache.org/dist/hadoop/common/stable/`](http://www.eu.apache.org/dist/hadoop/common/stable/).

Download the file to your home folder:

    FILE=$(wget "http://www.eu.apache.org/dist/hadoop/common/stable/" -O - | grep -Po "hadoop-[0-9].[0-9].[0-9].tar.gz" | head -n 1)
    URL=http://www.eu.apache.org/dist/hadoop/common/stable/$FILE
    wget -c "$URL" -O "$FILE"

Extract the downloaded file to `/usr/local/` directory and then rename the just extracted `hadoop-x.y.z` directory to `hadoop` and make yourself the owner:

    sudo tar xfz "$FILE" -C /usr/local
    sudo mv /usr/local/hadoop-*/ /usr/local/hadoop
    sudo chown -R $USER:$USER /usr/local/hadoop

##STEP 4: Editing Configuration Files  
Now we need to make changes to a few configuration files.

1. To append text to your `~/.bashrc` file, execute this block of code in the terminal:

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
        export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
        export HADOOP_CLASSPATH=${JAVA_HOME}/lib/tools.jar
        #HADOOP VARIABLES END
        EOT

2. To edit `/usr/local/hadoop/etc/hadoop/hadoop-env.sh` file, execute this block of code in the terminal:

        sed -i.bak -e 's/export JAVA_HOME=${JAVA_HOME}/export JAVA_HOME=$(readlink -f \/usr\/bin\/java | sed "s:jre\/bin\/java::")/g' /usr/local/hadoop/etc/hadoop/hadoop-env.sh

3. To edit `/usr/local/hadoop/etc/hadoop/core-site.xml` file, execute this block of code in the terminal:

        sed -n -i.bak '/<configuration>/q;p'  /usr/local/hadoop/etc/hadoop/core-site.xml
        cat << EOT >> /usr/local/hadoop/etc/hadoop/core-site.xml
        <configuration>
          <property>
             <name>fs.defaultFS</name>
             <value>hdfs://localhost:9000</value>
          </property>
        </configuration>
        EOT

4. To edit `/usr/local/hadoop/etc/hadoop/yarn-site.xml` file, execute this block of code in the terminal:

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

5. To genrate and then edit `/usr/local/hadoop/etc/hadoop/mapred-site.xml` file, execute this block of code in the terminal:

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

6. To make `~/hadoop_store/hdfs/namenode`, `~/hadoop_store/hdfs/datanode` folders and edit `/usr/local/hadoop/etc/hadoop/hdfs-site.xml` file, execute this block of code in the terminal:

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

##STEP 5: Formatting HDFS  
Before we can start using our hadoop cluster, we need to format the HDFS through the namenode.

Fomat the HDFS filesystem, answer password prompts if any:

    /usr/local/hadoop/bin/hdfs namenode -format

##STEP 6: Strating Hadoop daemons  

    /usr/local/hadoop/sbin/start-dfs.sh
    /usr/local/hadoop/sbin/start-yarn.sh

##Testing our installation  
##Troubleshooting
