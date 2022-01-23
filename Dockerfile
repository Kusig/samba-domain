FROM ubuntu:focal

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y

# Install basic packages
RUN apt-get install -y nano

# needed to make the init script work properly in any case
RUN apt-get install bash

# The third line is for multi-site config (ping is for testing later)
RUN apt-get install -y pkg-config
RUN apt-get install -y attr acl samba smbclient ldap-utils winbind libnss-winbind libpam-winbind krb5-user krb5-kdc supervisor ldb-tools
RUN apt-get install -y openvpn inetutils-ping

# apt-show-versions bug fix: https://groups.google.com/forum/#!topic/beagleboard/jXb9KhoMOsk
RUN rm -f /etc/apt/apt.conf.d/docker-gzip-indexes
RUN apt-get purge -y apt-show-versions
RUN rm -f /var/lib/apt/lists/*lz4
RUN apt-get -o Acquire::GzipIndexes=false update
RUN apt-get install -y apt-show-versions

# Install webmin dependencies
RUN apt-get install -y unzip wget libnet-ssleay-perl libauthen-pam-perl libio-pty-perl
RUN wget https://sourceforge.net/projects/webadmin/files/webmin/1.984/webmin_1.984_all.deb
RUN dpkg -i webmin_1.984_all.deb

SHELL ["/bin/bash", "-c"]

# Set up script and run
ADD init.sh /init.sh
RUN chmod 755 /init.sh

# Execute with the real bash in order to make the string substitutions work consistently
CMD bash /init.sh setup
