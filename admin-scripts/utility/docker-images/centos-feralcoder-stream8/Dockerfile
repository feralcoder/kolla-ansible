FROM quay.io/centos/centos:stream8

RUN cd /etc/yum.repos.d   &&   mkdir old-repos   && \
    mv CentOS-Stream-AppStream.repo  CentOS-Stream-BaseOS.repo  CentOS-Stream-Debuginfo.repo  CentOS-Stream-Extras.repo  CentOS-Stream-HighAvailability.repo  CentOS-Stream-Media.repo  CentOS-Stream-PowerTools.repo  CentOS-Stream-RealTime.repo old-repos && \
    touch CentOS-Stream-AppStream.repo  CentOS-Stream-BaseOS.repo  CentOS-Stream-Debuginfo.repo  CentOS-Stream-Extras.repo  CentOS-Stream-HighAvailability.repo  CentOS-Stream-Media.repo  CentOS-Stream-PowerTools.repo  CentOS-Stream-RealTime.repo



#COPY stack.crt /etc/pki/ca-trust/source/anchors/
#RUN update-ca-trust

COPY feralcoder.repo /etc/yum.repos.d/
RUN yum clean all   &&   yum makecache   &&   yum repolist

