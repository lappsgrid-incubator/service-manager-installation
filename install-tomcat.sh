#!/usr/bin/env bash

if [ -z "$OS" ] ; then
	source <(curl -sSL http://downloads.lappsgrid.org/scripts/sniff.sh)
fi

if [[ $OS = redhat || $OS = centos ]] ; then
    adduser -r -d /usr/share/tomcat -s /usr/bin/bash tomcat
elif [[ $OS = ubuntu ]] ; then
    groupadd tomcat
    adduser --system --home /usr/share/tomcat --shell /usr/bin/bash --ingroup tomcat tomcat
else
	echo "Unknown Linux flavor"
	exit 1
fi

wget http://downloads.lappsgrid.org/tomcat.tgz
tar xzf tomcat.tgz
mv tomcat /usr/share
chown -R tomcat:tomcat /usr/share/tomcat


if [[ $OS = centos ]] ; then
    wget http://downloads.lappsgrid.org/service-manager/tomcat.service
    mv tomcat.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable tomcat.service
elif [[ $OS = ubuntu || $OS = redhat ]] ; then
    wget http://downloads.lappsgrid.org/service-manager/tomcat.sh
    mv tomcat.sh /etc/init.d/tomcat
	update-rc.d tomcat defaults
else
	echo "Unknown Linux flavor... we should have failed already."
	exit 1
fi

echo "Tomcat installed to /usr/share/tomcat"
