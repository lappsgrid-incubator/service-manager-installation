#!/usr/bin/env bash

TOMCAT=/usr/share/tomcat
MANAGER=$TOMCAT/service-manager
BPEL=$TOMCAT/active-bpel

if [[ -z $JAVA_HOME ]] ; then
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
fi

function is_running()
{
    sudo ps aux | grep java | grep $1 > /dev/null
    return $?
}

function if_running()
{
    program=$1
    name=$2
    is_running $program
    if [ $? -eq 0 ] ; then
		echo "Stopping $name"
		sudo $program/shutdown.sh
	else
		echo "$name is already offline"
	fi
}

function if_not_running()
{
    program=$1
    name=$2
    is_running $program
    if [ $? -ne 0 ] ; then
		echo "Starting $name"
		sudo $program/startup.sh
	else
		echo "$name is already online."
	fi
}

function start()
{
    if_not_running $MANAGER/bin "Service Manager"
    sleep 1
    if_not_running $BPEL/bin "Active BPEL"
    sleep 1
}

function stop()
{
    if_running $MANAGER/bin "Service Manager"
    sleep 1
    if_running $BPEL/bin "Active BPEL"
    sleep 1
}

function status()
{
    is_running $MANAGER/bin
    if [ $? -eq 0 ] ; then
		echo "Service Manager: online"
	else
		echo "Service Manager: offline"
    fi
    
    is_running $BPEL/bin 
    if [ $? -eq 0 ] ; then
		echo "BPEL Server    : online"
	else
		echo "BPEL Server    : offline"
    fi
    echo
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
    for proc in `ps a | grep java | grep ServiceGrid | cut -d\  -f1` ; do
		echo "Killing zombie process $proc"
		sudo kill -9 $proc
	done
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
