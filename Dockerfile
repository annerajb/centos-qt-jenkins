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

ENV datadir /var/data
ENV appname jenkins
ENV appversion 1.617
ENV portoffset 90
ENV JAVA_OPTIONS -Xmx1024m
ENV JENKINS_OPTIONS --httpPort=80${portoffset}
ENV JENKINS_HOME ${datadir}/${appname}

# create data directory
RUN mkdir -p /var/data

# create user
RUN adduser -u 10${portoffset} -U ${appname} -b ${datadir}

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
           build-essential \
           openssh-clients \
           Xvfb \
           -y && yum clean all -y

# install Development tools
RUN yum groupinstall --quiet "Development Tools" -y

# get java
RUN wget --quiet --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u45-b14/jdk-8u45-linux-x64.tar.gz -O /opt/jdk18.tar.gz && cd /opt && tar xfz jdk18.tar.gz && ln -s /opt/jdk1.8* /opt/jdk18 && rm -rf /opt/*.tar.gz

# add java opts to .bashrc file
RUN echo "export JAVA_OPTIONS=${JAVA_OPTIONS}" >> ${JENKINS_HOME}/.bashrc

ADD qt-installer-noninteractive.qs /tmp/qt/script.qs
ADD http://download.qt.io/official_releases/qt/${QTM}/${QT}/qt-opensource-linux-x64-${QT}.run /tmp/qt/installer.run

RUN echo "${QTSHA}  /tmp/qt/installer.run" | shasum -a 256 -c \
    && chmod +x /tmp/qt/installer.run \
    && xvfb-run /tmp/qt/installer.run --script /tmp/qt/script.qs \
     | egrep -v '\[[0-9]+\] Warning: (Unsupported screen format)|((QPainter|QWidget))' \
    && rm -rf /tmp/qt

RUN echo /opt/qt/${QTM}/gcc_64/lib > /etc/ld.so.conf.d/qt-${QTM}.conf
RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/qt/${QTM}/gcc_64/bin

# create custom run.sh
RUN wget --quiet http://mirrors.jenkins-ci.org/war/latest/jenkins.war -O /opt/jenkins.war && chown ${appname}:${appname} /opt/jenkins.war

# create custom run.sh
RUN echo "/opt/jdk18/bin/java ${JAVA_OPTS} -jar /opt/jenkins.war ${JENKINS_OPTIONS}" >> /opt/run.sh

# start jenkins on container start
CMD su - jenkins -c "sh /opt/run.sh"
