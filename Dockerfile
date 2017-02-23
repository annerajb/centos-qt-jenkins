FROM centos:latest

MAINTAINER Chema Durán <jgduran@gmail.com>

ARG QT=5.7.1
ARG QTM=5.7
ARG QTSHA=fdf6b4fb5ee9ade2dec74ddb5bea9e1738911e7ee333b32766c4f6527d185eb4
ARG VCS_REF
ARG BUILD_DATE

LABEL org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="qt-build" \
      org.label-schema.description="A headless Qt $QTM build environment for Centos 7" \
      org.label-schema.url="e.g. https://github.com/chemaduran/centos-qt-jenkins" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.vcs-url="https://github.com/chemaduran/centos-qt-jenkins.git" \
      org.label-schema.version="$QT" \
      org.label-schema.schema-version="1.0"

ENV datadir /var/
ENV appname jenkins_home
ENV appversion 1.617
ENV portoffset 90
ENV JAVA_OPTIONS -Xmx1024m
ENV JENKINS_OPTIONS --httpPort=80${portoffset}
ENV JENKINS_HOME ${datadir}/${appname}
ENV JENKINS_SLAVE_AGENT_PORT 50000

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# create data directory
RUN mkdir -p /var/data

# create user
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

VOLUME /var/jenkins_home

# setting up locale
RUN echo "LC_ALL=en_US.UTF-8" >> ${JENKINS_HOME}/.bashrc

# install basic tools
RUN yum install --quiet  \
           git \
           subversion \
           cmake \
           vim \
           wget \
           curl \
           tar \
           fontconfig \
           libSM  \
           libICE \
           libX11 \
           libX11-devel \
           libxcb \
           libxcb-devel \
           xcb-util \
           xcb-util-devel \
           libXext \
           libXrender \
           mesa-libGL-devel \
           python-devel \
           python-lxml \
           build-essential \
           openssh-clients \
           java-1.8.0-openjdk.x86_64 \
           Xvfb \
           -y && yum clean all -y

# install Development tools
RUN yum groupinstall --quiet "Development Tools" -y
 
# Virtualbox
RUN cd /etc/yum.repos.d && wget http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo && yum install VirtualBox-5.1 -y

## Boost 1.63
RUN wget -O /boost_1_63_0.tar.bz2 -c 'http://sourceforge.net/projects/boost/files/boost/1.63.0/boost_1_63_0.tar.bz2/download' && \
    tar xjf /boost_1_63_0.tar.bz2 && \
    cd /boost_1_63_0/ && \
    ./bootstrap.sh "--prefix=/opt/boost_1_63_0" && \
    ./b2 install && \
    rm -rf /boost_1_63_0.tar.bz2 /boost_1_63_0

# OpenDDS
RUN wget -O /OpenDDS-3.10.tar.gz -c 'https://github.com/objectcomputing/OpenDDS/releases/download/DDS-3.10/OpenDDS-3.10.tar.gz' && \
    tar xzf /OpenDDS-3.10.tar.gz && \
    cd /OpenDDS-3.10/ && \
    ./configure && \
    make && \
    rm -rf /OpenDDS-3.10.tar.gz

# Get java
RUN wget --quiet --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u45-b14/jdk-8u45-linux-x64.tar.gz -O /opt/jdk18.tar.gz && cd /opt && tar xfz jdk18.tar.gz && ln -s /opt/jdk1.8* /opt/jdk18 && rm -rf /opt/*.tar.gz

# add java opts to .bashrc file
RUN echo "export JAVA_OPTIONS=${JAVA_OPTIONS}" >> ${JENKINS_HOME}/.bashrc

ADD qt-installer-noninteractive.qs /tmp/qt/script.qs
ADD http://download.qt.io/official_releases/qt/${QTM}/${QT}/qt-opensource-linux-x64-${QT}.run /tmp/qt/installer.run

RUN echo "${QTSHA}  /tmp/qt/installer.run" | sha256sum -c \
    && chmod +x /tmp/qt/installer.run \
    && xvfb-run /tmp/qt/installer.run --script /tmp/qt/script.qs \
     | egrep -v '\[[0-9]+\] Warning: (Unsupported screen format)|((QPainter|QWidget))' \
    && rm -rf /tmp/qt

RUN echo /opt/qt/${QTM}/gcc_64/lib > /etc/ld.so.conf.d/qt-${QTM}.conf
#RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/qt/${QTM}/gcc_64/bin

RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_VERSION 0.13.2
ENV TINI_SHA afbf8de8a63ce8e4f18cb3f34dfdbbd354af68a1

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.32.2}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=f495a08733f69b1845fd2d9b3a46482adb6e6cee

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

USER root

RUN chmod +x /usr/local/bin/*
