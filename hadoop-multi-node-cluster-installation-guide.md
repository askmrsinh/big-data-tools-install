---
layout: page
title: Hadoop Multi-Node Cluster Installation Guide
---


**Hadoop (2.7.1) Multi-Node cluster configuration**

1. Make sure that you have a reliable network without host isolation. Static IP assignment is preferable or at-least have extremely long DHCP lease. Additionally all nodes (Namenode/master & Datanodes/slaves) should have a common user account with same password; in case you don't, make such user account on all nodes. Having same username and password on all nodes makes things a bit less complicated.
2. *[on all machines]* First configure all nodes for single-node cluster. You can use my script that I have posted over [here](https://github.com/user501254/BD_STTP_2016/blob/master/InstallHadoop.sh).
3. execute these commands in a new terminal
   
    *[on all machines]* ↴

        stop-dfs.sh;stop-yarn.sh;jps
        rm -rf /tmp/hadoop-$USER

    *[on Namenode/master only]* ↴

        rm -rf ~/hadoop_store/hdfs/datanode

    *[on Datanodes/slaves only]* ↴

        rm -rf ~/hadoop_store/hdfs/namenode
4. *[on all machines]* Add IP addresses and corresponding Host names for all nodes in the cluster. 
            
        sudo nano /etc/hosts

    hosts

        xxx.xxx.xxx.xxx master
        xxx.xxx.xxx.xxy slave1
        xxx.xxx.xxx.xxz slave2
        # Additionally you may need to remove lines like "xxx.xxx.xxx.xxx localhost", "xxx.xxx.xxx.xxy localhost", "xxx.xxx.xxx.xxz localhost" etc if they exist.
        # However it's okay keep lines like "127.0.0.1 localhost" and others.
    
5. *[on all machines]* Configure iptables

    Allow default or custom ports that you plan to use for various Hadoop daemons through the firewall 

    OR 

    much easier, disable iptables
    - on RedHat like distros (Fedora, CentOS)

            sudo systemctl disable firewalld
            sudo systemctl stop firewalld
    - on Debian like distros (Ubuntu)

            sudo ufw disable

6. *[on Namenode/master only]* Gain ssh access from Namenode (master) to all Datnodes (slaves).

        ssh-copy-id -i ~/.ssh/id_rsa.pub $USER@slave1
        ssh-copy-id -i ~/.ssh/id_rsa.pub $USER@slave2
    confirm things by running `ping slave1`, `ssh slave1`, `ping slave2`, `ssh slave2` etc. You should have a proper response. (Remember to exit each of your ssh sessions by typing `exit` or closing the terminal. To be on the safer side I also made sure that all nodes were able to access each other and not just the Namenode/master.)
7. *[on all machines]* edit core-site.xml file

        nano /usr/local/hadoop/etc/hadoop/core-site.xml
   core-site.xml

        <configuration>
            <property>
                <name>fs.defaultFS</name>
                <value>hdfs://master:9000</value>
                <description>NameNode URI</description>
            </property>
        </configuration>
8. *[on all machines]* edit yarn-site.xml file

        nano /usr/local/hadoop/etc/hadoop/yarn-site.xml
   yarn-site.xml

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
9. *[on all machines]* modify slaves file, remove the text "localhost" and add slave hostnames

        nano /usr/local/hadoop/etc/hadoop/slaves
   slaves

        slave1
        slave2
    (I guess having this only on Namenode/master will also work but I did this on all machines anyway. Also note that in this configuration master behaves only as resource manger, this is how I intent it to be.)
10. *[on all machines]* modify hdfs-site.xml file to change the value for property `dfs.replication` to something > 1 (at-least to the number of slaves in the cluster; here I have two slaves so I would set it to 2)
11. *[on Namenode/master only]* (re)format the HDFS through namenode

        hdfs namenode -format
12. *[optional]*
    - remove `dfs.datanode.data.dir` property from master's hdfs-site.xml file.
    - remove `dfs.namenode.name.dir` property from all slave's hdfs-site.xml file.


**TESTING (execute only on Namenode/master)**

    start-dfs.sh;start-yarn.sh

    echo "hello world hello Hello" > ~/Downloads/test.txt

    hadoop fs -mkdir /input

    hadoop fs -put ~/Downloads/test.txt /input

    hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.1.jar wordcount /input /output

wait for a few seconds and the mapper and reducer should begin.
