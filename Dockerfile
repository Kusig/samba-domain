FROM ubuntu:xenial
LABEL manteiner="celsoalexandre <celsoalexandre@NOSPAM.NO>"

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y

# Install all apps
# The third line is for multi-site config (ping is for testing later)
RUN apt-get install -y pkg-config
RUN apt-get install -y attr acl samba smbclient ldap-utils winbind libnss-winbind libpam-winbind krb5-user krb5-kdc supervisor
RUN apt-get install -y openvpn inetutils-ping

# apt-show-versions bug fix: https://groups.google.com/forum/#!topic/beagleboard/jXb9KhoMOsk
RUN rm -f /etc/apt/apt.conf.d/docker-gzip-indexes
RUN apt-get purge -y apt-show-versions
RUN rm -f /var/lib/apt/lists/*lz4
RUN apt-get -o Acquire::GzipIndexes=false update
RUN apt-get install -y apt-show-versions

# Install webmin dependencies
RUN apt-get install -y unzip wget nano
RUN wget https://prdownloads.sourceforge.net/webadmin/webmin_1.941_all.deb
RUN dpkg -i webmin_1.941_all.deb
RUN apt install -fy

# Set up script and run
ADD init.sh /init.sh
RUN chmod 755 /init.sh
CMD /init.sh setup
