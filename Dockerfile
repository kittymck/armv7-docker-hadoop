# docker build -t hadoop .

FROM resin/rpi-raspbian:jessie
MAINTAINER kittymck

USER root

# install dev tools
RUN apt-get update && apt-get install -y apt-utils
RUN apt-get install -y curl tar sudo openssh-server openssh-client rsync libselinux1
# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14
# RUN apt-get upgrade -y libselinux

# passwordless ssh
RUN rm /etc/ssh/ssh_host_dsa_key && ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN rm /etc/ssh/ssh_host_rsa_key && ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys


# java
RUN apt-get update && apt-get install -y \
    openjdk-7-jre \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*
#RUN curl -LO 'http://download.oracle.com/otn-pub/java/jdk/7u51-b13/jdk-7u51-linux-x64.rpm' -H 'Cookie: oraclelicense=accept-securebackup-cookie'
#RUN rpm -i jdk-7u51-linux-x64.rpm
#RUN rm jdk-7u51-linux-x64.rpm
# Define commonly used JAVA_HOME variable

ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-armhf
ENV PATH $PATH:$JAVA_HOME/bin

# hadoop
RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./hadoop-2.6.0 hadoop

ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV HADOOP_CLASSPATH /usr/lib/jvm/java-7-openjdk-armhf/lib/tools.jar

RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
#RUN . $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

RUN mkdir $HADOOP_PREFIX/input
RUN cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_PREFIX/input

# pseudo distributed
RUN mkdir -p $HADOOP_PREFIX/etc/hadoop
ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml
ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
ADD mapred-site.xml $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
ADD yarn-site.xml $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

# Fix guava issue by updating it to v15

#RUN mkdir -p /usr/java/default/bin && ln -s $(which java) /usr/java/default/bin/java
#RUN rm $HADOOP_PREFIX/share/hadoop/hdfs/lib/guava-11.0.2.jar && curl -o $HADOOP_PREFIX/share/hadoop/hdfs/lib/guava-11.0.2.jar https://repo1.maven.org/maven2/com/google/guava/guava/15.0/guava-15.0.jar
#RUN for file in $(find . -iname guava-11.0.2.jar); do cp $HADOOP_PREFIX/share/hadoop/hdfs/lib/guava-11.0.2.jar $file; done

RUN $HADOOP_PREFIX/bin/hdfs namenode -format

# fixing the libhadoop.so like a boss -NOT SURE IF NECESSARY
#RUN rm  /usr/local/hadoop/lib/native/*
#RUN curl -Ls http://dl.bintray.com/sequenceiq/sequenceiq-bin/hadoop-native-64-2.6.0.tar | tar -x -C /usr/local/hadoop/lib/native/


## installing supervisord
# RUN apt-get install -y python-setuptools
# RUN easy_install pip
# RUN curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -o - | python
# RUN pip install supervisor
#
# ADD supervisord.conf /etc/supervisord.conf

ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

# workingaround docker.io build error
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh
RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

RUN service ssh start && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/root
RUN service ssh start && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -put $HADOOP_PREFIX/etc/hadoop/ input

CMD ["/etc/bootstrap.sh", "-d"]

EXPOSE 50020 50090 50070 50010 50075 8031 8032 8033 8040 8042 49707 22 8088 8030
