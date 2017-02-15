#!/usr/bin/env bash

if [ -z "$OS" ] ; then
	source <(curl -sSL http://downloads.lappsgrid.org/scripts/sniff.sh)
fi

if [[ $OS = redhat || $OS = centos ]] ; then
    adduser -r -d /usr/share/tomcat -s /usr/bin/bash tomcat
elif [[ $OS = ubuntu ]] ; then
    adduser --system --home /usr/share/tomcat --shell /usr/bin/bash tomcat
else
	echo "Unknown Linux flavor"
	exit 1
fi

wget http://downloads.lappsgrid.org/tomcat.tgz
tar xzf tomcat.tgz
mv tomcat /usr/share
chown -R tomcat:tomcat /usr/share/tomcat


if [[ $OS = centos ]] ; then
    wget http://downloads.lappsgrid.org/keith/tomcat.service
    mv tomcat.service /etc/systemd/system/
	systemctl start tomcat.service
	systemctl enable tomcat.service
elif [[ $OS = ubuntu || $OS = redhat ]] ; then
    wget http://downloads.lappsgrid.org/keith/tomcat.sh
    mv tomcat.sh /etc/init.d
	update-rc.d tomcat defaults
else
	echo "Unknown Linux flavor... we should have failed already."
	exit 1
fi

echo "Tomcat installed to /usr/share/tomcat"