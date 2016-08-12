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

RUN wget "https://storage.googleapis.com/golang/go1.6.3.linux-amd64.tar.gz"
RUN tar -C /usr/local -xzf go1.6.3.linux-amd64.tar.gz
RUN rm go1.6.3.linux-amd64.tar.gz
RUN mkdir ~/go

ENV GOPATH=~/go
ENV PATH=${PATH}:${GOPATH}/bin


RUN apt-get install -y unzip xvfb qt5-default libqt5webkit5-dev gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-x


# Install Chrome WebDriver
RUN CHROMEDRIVER_VERSION='2.21' && \
    mkdir -p /opt/chromedriver-$CHROMEDRIVER_VERSION && \
    curl -sS -o /tmp/chromedriver_linux64.zip http://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip && \
    unzip -qq /tmp/chromedriver_linux64.zip -d /opt/chromedriver-$CHROMEDRIVER_VERSION && \
    rm /tmp/chromedriver_linux64.zip && \
    chmod +x /opt/chromedriver-$CHROMEDRIVER_VERSION/chromedriver && \
    ln -fs /opt/chromedriver-$CHROMEDRIVER_VERSION/chromedriver /usr/local/bin/chromedriver



# Install Google Chrome
RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list && \
apt-get -yqq update && \
apt-get -yqq install google-chrome-stable && \
rm -rf /var/lib/apt/lists/*

# Disable the SUID sandbox so that Chrome can launch without being in a privileged container.
# One unfortunate side effect is that `google-chrome --help` will no longer work.
RUN dpkg-divert --add --rename --divert /opt/google/chrome/google-chrome.real /opt/google/chrome/google-chrome && \
echo "#!/bin/bash\nexec /opt/google/chrome/google-chrome.real --disable-setuid-sandbox \"\$@\"" > /opt/google/chrome/google-chrome && \
chmod 755 /opt/google/chrome/google-chrome


#===============
#Last Actions
#===============

RUN apt-get clean
RUN apt-get autoremove

USER jenkins
