---
layout: page
title: Hadoop Multi-Node Cluster Installation Guide
---

## Prerequisites

Make sure that you have a reliable network without host isolation. Static IP assignment is preferable or at-least have extremely long DHCP lease. Additionally, all nodes (Namenode/master & Datanodes/slaves) should have a common user account with same password; in case you don't, make such user account on all nodes. Having the same username and password on all nodes makes things a bit less complicated.  
First configure all nodes for single-node cluster. You can use my script that I have posted over [here](https://github.com/user501254/BD_STTP_2016/blob/master/InstallHadoop.sh).

## STEP 1: Stopping Hadoop Daemons and cleaning up HDFS files 

1. **On all nodes**, confirm that the daemons have stopped by running `jps` command.  
    `stop-dfs.sh; stop-yarn.sh; rm -rf /tmp/hadoop-$USER`

2. **On Namenode/master only**, remove the datanode directory from HDFS.  
  `rm -rf ~/hadoop_store/hdfs/datanode`

3. **On Datanodes/slaves only**, remove the namenode directory from HDFS.  
   `rm -rf ~/hadoop_store/hdfs/namenode`


## STEP 2: Configuring connectivity

1. **On all nodes**, add IP addresses and corresponding Hostnames for all nodes in the cluster.  
    `sudo nano /etc/hosts`

    The `/etc/hosts` file should look somewhat like this after you edit it.

        xxx.xxx.xxx.xxx master
        xxx.xxx.xxx.xxy slave1
        xxx.xxx.xxx.xxz slave2

    Additionally you may need to remove lines like 
    "xxx.xxx.xxx.xxx localhost" etc if they exist.
    However it's okay keep lines like "127.0.0.1 localhost" and others.

2. **On all nodes**, configure the firewall

    Allow default or custom ports that you plan to use for various Hadoop daemons through the firewall.

    OR 

    Much easier, disable Firewall `iptables` (never on production system).

    - on RedHat like distros (Fedora, CentOS)  
      `sudo systemctl stop firewalld; sudo systemctl disable firewalld`

    - on Debian like distros (Ubuntu)  
       `sudo ufw disable`

3. **On Namenode/master only**, gain `ssh` access from Namenode (master) to all Datnodes (slaves).

    `ssh-copy-id -i ~/.ssh/id_rsa.pub $USER@slave1`
    
    Then confirm connectivity by running `ping slave1`, `ssh slave1`.
    
    `ssh-copy-id -i ~/.ssh/id_rsa.pub $USER@slave2`
    
    Then confirm connectivity by running `ping slave2`, `ssh slave2`.
    
    Make sure taht you get a proper response. 
    Remember to exit each of your ssh sessions by typing `exit` or closing the terminal. 
    To be on the safer side, also made sure that all datanodes are also able to access each other.


## STEP 3: Editing Configuration Files

1. **On all nodes**, edit Hadoop's `core-site.xml` file

    `nano /usr/local/hadoop/etc/hadoop/core-site.xml`

    ```xml
    <configuration>
        <property>
            <name>fs.defaultFS</name>
            <value>hdfs://master:9000</value>
            <description>NameNode URI</description>
        </property>
    </configuration>
    ```

2. **On all nodes**, edit Hadoop's `yarn-site.xml` file

    `nano /usr/local/hadoop/etc/hadoop/yarn-site.xml `

    ```xml
    <configuration>
        <property>
            <name>yarn.resourcemanager.hostname</name>
            <value>master</value>
            <description>The hostname of the RM.</description>
        </property>
        <property>
             <name>yarn.nodemanager.aux-services</name>
             <value>mapreduce_shuffle</value>
        </property>
        <property>
             <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
             <value>org.apache.hadoop.mapred.ShuffleHandler</value>
        </property>
    </configuration>
    ```

7. **On all nodes**, edit Hadoop's `slaves` file, remove the text "localhost" and add slave hostnames

    `nano /usr/local/hadoop/etc/hadoop/slaves`

        slave1's hostname
        slave2's hostname

    I guess having this only on Namenode/master will also work but I did this on all nodes anyway.
    Also note that in this configuration master behaves only as resource manger, this is how I intent it to be.

8. **On all nodes**, modify `hdfs-site.xml` file to change the value for property `dfs.replication` to something > 1. It should be equal to at-least the number of slaves in the cluster; here I have two slaves so I would set it to 2.

9. **On Namenode/master only**, (re)format the HDFS through namenode

    `hdfs namenode -format`

10. **Optional**
    - remove `dfs.datanode.data.dir` property from master's `hdfs-site.xml` file.
    - remove `dfs.namenode.name.dir` property from all slave's `hdfs-site.xml` file.


## Testing our setup (execute only on Namenode/master)

    start-dfs.sh; start-yarn.sh

    echo "hello world hello Hello" > ~/Downloads/test.txt

    hadoop fs -mkdir /input
    hadoop fs -put ~/Downloads/test.txt /input
    hadoop jar \
      /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
      wordcount \
      /input /output
