FROM ubuntu:22.04

RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker

RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update \
  && apt-get install -y wget \
  && apt-get install -y curl \
  && apt-get install -y vim \
  && apt-get install -y apt-utils \
  && apt-get install -y net-tools \
  && apt-get install -y iputils-ping \
  && apt-get install -y ssh \
  && apt-get install -y less \
  && apt-get install -y python3 

RUN DEBIAN_FRONTEND=noninteractive rm -rf /var/lib/apt/lists/*

ENV ETCD_VER=v3.5.13
ENV GOOGLE_URL=http://storage.googleapis.com/etcd
ENV GITHUB_URL=http://github.com/etcd-io/etcd/releases/download
ENV DOWNLOAD_URL=${GOOGLE_URL}

RUN rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
RUN rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test
RUN curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
RUN tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
RUN rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
RUN cp -p /tmp/etcd-download-test/etcd /usr/bin/
RUN cp -p /tmp/etcd-download-test/etcdctl /usr/bin/
RUN cp -p /tmp/etcd-download-test/etcdutl /usr/bin/
RUN cd /tmp
RUN rm -rf /tmp/etcd-download-test

#ADD etcd /usr/local/bin/
#ADD etcdctl /usr/local/bin/
#ADD etcdutl /usr/local/bin/

#WORKDIR /var/etcd/
WORKDIR /var/lib/etcd/

EXPOSE 2379 2380

CMD ["/usr/bin/etcd"]





