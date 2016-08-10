FROM ubuntu:15.04
MAINTAINER CF Engineering <cfengineering@allstate.com>

#================================================
# Customize sources for apt-get
#================================================
RUN  echo "deb http://archive.ubuntu.com/ubuntu vivid main universe\n" > /etc/apt/sources.list \
  && echo "deb http://archive.ubuntu.com/ubuntu vivid-updates main universe\n" >> /etc/apt/sources.list

RUN apt-get update -qqy \
  && apt-get -qqy --no-install-recommends install software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa

#========================
# Miscellaneous packages
# iproute which is surprisingly not available in ubuntu:15.04 but is available in ubuntu:latest
# OpenJDK8
# rlwrap is for azure-cli
# groff is for aws-cli
# tree is convenient for troubleshooting builds
#========================
RUN apt-get update -qqy \
  && apt-get -qqy --no-install-recommends install \
    iproute \
    ca-certificates \
    tar zip unzip \
    wget curl \
    git \
    telnet \
    build-essential \
    less nano tree \
    python \
    software-properties-common python-software-properties\
    rlwrap \
    sudo \
  && rm -rf /var/lib/apt/lists/*

#================
#Java 8
#===============

RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
RUN add-apt-repository ppa:webupd8team/java
RUN apt-get update -qqy \
  && apt-get -qqy --no-install-recommends install \
    oracle-java8-installer

RUN apt-get install oracle-java8-set-default

#==================================
# Install Allstate CA certificates
# =================================
COPY allstate-certs/ /tmp/allstate-certs
RUN cp /tmp/allstate-certs/* /usr/local/share/ca-certificates/ && update-ca-certificates \
   && keytool -import -trustcacerts -alias polaris -file /tmp/allstate-certs/polaris.crt -storepass changeit -keystore /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts -noprompt \
   && keytool -import -trustcacerts -alias aries -file /tmp/allstate-certs/aries.crt -storepass changeit -keystore /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts -noprompt \
   && keytool -import -trustcacerts -alias ariesroot -file /tmp/allstate-certs/ariesroot.crt -storepass changeit -keystore /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts -noprompt

#========================================
# Add normal user with passwordless sudo
#========================================
RUN useradd jenkins --shell /bin/bash --create-home \
  && usermod -a -G sudo jenkins \
  && echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers \
  && echo 'jenkins:secret' | chpasswd

#====================================
# Cloud Foundry CLI
# https://github.com/cloudfoundry/cli
#====================================
RUN wget -O - "http://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -C /usr/local/bin -zxf -

#===================================
# Install Go
#===================================

RUN apt-get -y install libxss1 libappindicator1 libindicator7 \
    && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

RUN apt-get -y install xvfb
RUN apt-get -y install unzip
RUN wget -N http://chromedriver.storage.googleapis.com/2.20/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip
RUN chmod +x chromedriver

RUN mv -f chromedriver /usr/local/share/chromedriver \
    && ln -s /usr/local/share/chromedriver /usr/local/bin/chromedriver \
    && ln -s /usr/local/share/chromedriver /usr/bin/chromedriver

RUN dpkg -i google-chrome*.deb
RUN apt-get install -f

RUN curl -k "https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz" \
    && tar -C /usr/local -xzf go1.6.2.linux-amd64.tar.gz \
    && rm go1.6.2.linux-amd64.tar.gz \
    && mkdir ~/go

ENV GOPATH=~/go
ENV PATH=${PATH}:${GOPATH}/bin



#===============
#Last Actions
#===============

RUN apt-get clean
RUN apt-get autoremove

USER jenkins
