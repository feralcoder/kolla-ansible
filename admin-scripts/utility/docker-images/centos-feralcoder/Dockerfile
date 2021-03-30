FROM centos:8

RUN cd /etc/yum.repos.d   &&   mkdir old-repos   && \
    mv CentOS-Linux-AppStream.repo CentOS-Linux-BaseOS.repo CentOS-Linux-Devel.repo CentOS-Linux-HighAvailability.repo CentOS-Linux-Plus.repo CentOS-Linux-Extras.repo CentOS-Linux-PowerTools.repo  CentOS-Linux-ContinuousRelease.repo CentOS-Linux-FastTrack.repo old-repos

COPY stack.crt /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust

COPY feralcoder.repo /etc/yum.repos.d/
RUN yum clean all   &&   yum makecache   &&   yum repolist

