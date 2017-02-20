#!/usr/bin/env bash

### BEGIN INIT INFO
# Provides:        tomcat7
# Required-Start:  $network
# Required-Stop:   $network
# Default-Start:   2 3 4 5
# Default-Stop:    0 1 6
# Short-Description: Start/Stop Tomcat server
### END INIT INFO

TOMCAT=/usr/share/tomcat
MANAGER=$TOMCAT/service-manager
BPEL=$TOMCAT/active-bpel

if [[ -z $JAVA_HOME ]] ; then
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
fi

function getpid()
{
    echo `ps aux | grep $1 | grep -v grep | awk '{print $2}'`
}

function start()
{
	for server in service-manager active-bpel ; do
		local pid=$(getpid $server)
		if [[ -z $pid ]] ; then
			$TOMCAT/$server/bin/startup.sh
		else
			echo "$server is already running: $pid"
		fi
	done
}

function stop()
{
	for server in service-manager active-bpel ; do
		local pid=$(getpid $server)
		if [[ -n $pid ]] ; then
			$TOMCAT/$server/bin/shutdown.sh
		else
			echo "$server is not running."
		fi
	done
}

function status()
{
	local pid=$(getpid service-manager)
	if [[ -n $pid ]] ; then
		echo "Service Manager: $pid"
	else
		echo "Service Manager: offline"
    fi
    
	pid=$(getpid active-bpel)
	if [[ -n $pid ]] ; then
		echo "BPEL Server: $pid"
	else
		echo "BPEL Server: offline"
    fi
}

function usage()
{
    echo
    echo "USAGE" 
    echo "    tomcat [start|stop|status|restart|force-stop|force-restart"
    echo
}

function kill_tomcat()
{
    echo "Killing zombie tomcat instances."
    ps aux | grep bootstrap.jar | grep -v grep | awk '{print $2}' | xargs kill -9
}

case $1 in
    start)
		echo "Starting the Service Grid."
		start 
		echo "Done"
		;;
    stop)
		echo "Stopping the Service Grid."
		stop
		echo "Done"
		;;
    status)
		status
		;;
    restart)
		echo "Restarting the Service Grid."
		stop 
		sleep 5
		start
		echo "Done"
		;;
    force-stop)
		echo "Killing all Tomcat instances."
		stop
		echo "Waiting for tomcat to quit cleanly."
		sleep 5
		kill_tomcat 
		echo "Done."
		;;
    force-restart)
		echo "Forcing a restart."
		stop
		sleep 5
		kill_tomcat
		sleep 2
		start
		echo "Done."
		;;
    *)
		echo "Unknown command $1"
		usage
		;;
esac
