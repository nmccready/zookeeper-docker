FROM openjdk:8-jre-alpine

MAINTAINER nmccready

# Note mirror.vorboss.net only holds onto the latest 3 releases per minor (3.4.10|12|13)
ENV ZOOKEEPER_VERSION 3.4.13

# BEGIN gpg
# shamelessly copied from https://hub.docker.com/r/vladgh/gpg/~/dockerfile/

# Install packages
RUN apk --no-cache add gnupg haveged tini

# Entrypoint
# ENTRYPOINT ["/sbin/tini", "--", "gpg"]
# CMD ["--version"]

# Metadata params
ARG VERSION
ARG VCS_URL
ARG VCS_REF
ARG BUILD_DATE

# Metadata
LABEL org.label-schema.name="VGH GPG" \
      org.label-schema.url="$VCS_URL" \
      org.label-schema.vendor="Vlad Ghinea" \
      org.label-schema.license="Apache-2.0" \
      org.label-schema.version="$VERSION" \
      org.label-schema.vcs-url="$VCS_URL" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.docker.schema-version="1.0"

# END gpg

RUN apk add --no-cache bash wget sed unzip supervisor openssh-server openssh-keygen \
    && mkdir /opt \
    # build out required keys
    && ssh-keygen -b 2048 -t rsa -f /etc/ssh/ssh_host_rsa_key -q -N "" \
    && ssh-keygen -b 521 -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -q -N "" \
    && ssh-keygen -b 521 -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -q -N ""

#Download Zookeeper
RUN wget -q http://mirror.vorboss.net/apache/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/zookeeper-${ZOOKEEPER_VERSION}.tar.gz && \
wget -q https://www.apache.org/dist/zookeeper/KEYS && \
wget -q https://www.apache.org/dist/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/zookeeper-${ZOOKEEPER_VERSION}.tar.gz.asc && \
wget -q https://www.apache.org/dist/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/zookeeper-${ZOOKEEPER_VERSION}.tar.gz.md5

#Verify download
RUN md5sum -c zookeeper-${ZOOKEEPER_VERSION}.tar.gz.md5 && \
gpg --import KEYS && \
gpg --verify zookeeper-${ZOOKEEPER_VERSION}.tar.gz.asc

#Install
RUN tar -xzf zookeeper-${ZOOKEEPER_VERSION}.tar.gz -C /opt

#Configure
RUN mv /opt/zookeeper-${ZOOKEEPER_VERSION}/conf/zoo_sample.cfg /opt/zookeeper-${ZOOKEEPER_VERSION}/conf/zoo.cfg

ENV JAVA_HOME /usr/lib/jvm/default-jvm
ENV ZK_HOME /opt/zookeeper-${ZOOKEEPER_VERSION}
RUN sed  -i "s|/tmp/zookeeper|$ZK_HOME/data|g" $ZK_HOME/conf/zoo.cfg; mkdir $ZK_HOME/data

ADD start-zk.sh /usr/bin/start-zk.sh 
EXPOSE 2181 2888 3888

WORKDIR /opt/zookeeper-${ZOOKEEPER_VERSION}
VOLUME ["/opt/zookeeper-${ZOOKEEPER_VERSION}/conf", "/opt/zookeeper-${ZOOKEEPER_VERSION}/data"]

CMD /usr/sbin/sshd && bash /usr/bin/start-zk.sh
