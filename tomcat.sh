#!/bin/bash

### BEGIN INIT INFO
# Provides:    tomcat
# Description: Control script for Tomcat. 
### END INIT INFO

if [ -z "$JAVA_HOME" ] ; then
	#JAVA_HOME=/usr/lib/jvm/java-7-oracle
	JAVA_HOME=java-8-openjdk-amd64
fi

TOMCAT_ROOT=/usr/share/tomcat
MANAGER=$TOMCAT_ROOT/service-manager
BPEL=$TOMCAT_ROOT/active-bpel
TOMCAT_USER=tomcat

function start()
{
	sudo -u $TOMCAT_USER $MANAGER/bin/startup.sh
	sudo -u $TOMCAT_USER $BPEL/bin/startup.sh
}

function stop()
{
	sudo -u $TOMCAT_USER $MANAGER/bin/shutdown.sh
	sudo -u $TOMCAT_USER $BPEL/bin/shutdown.sh
}

case $1 in
	start)
		echo -n "Staring Tomcat instances"
		start
		echo "Done."
		;;
	stop)
		echo "Stopping Tomcat instances"
		stop
		echo "Done."
		;;
	restart)
		echo "Restarting Tomcat instances"
		stop
		sleep 5
		start
		echo "Done"
		;;
	force-reload)
		echo "Forcing Tomcat instances to restart."
		stop
		sleep 5
		ps a | grep tomcat | grep java | cut -d\  -f2 | xargs kill -9
		sleep 4
		start
		echo "Done."
		;;
	status)
		echo "Unsupported option: status"
		;;
esac
