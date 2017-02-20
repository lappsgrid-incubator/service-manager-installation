#!/usr/bin/env bash
set -u

smg=smg-1.1.0-SNAPSHOT
manager=http://downloads.lappsgrid.org/service-manager
scripts=http://downloads.lappsgrid.org/scripts

# Locations that Tomcat is installed.
MANAGER=/usr/share/tomcat/service-manager
BPEL=/usr/share/tomcat/active-bpel

function usage()
{
	echo
	echo "USAGE"
	echo "   sudo ./setup.sh"
	echo
	echo
}

function log {
	echo $1
	echo "$(date +'%b %d %Y %Y') - $1" >> /var/log/service-manager-install.log 
}

function start_tomcat {
	log "Staring tomcat."
	if [[ $OS = redhat7 || $OS = centos ]] ; then
		systemctl start tomcat
	else
		service tomcat start
	fi
}

function stop_tomcat {
	log "Stopping tomcat."
	if [[ $OS = redhat7 || $OS = centos ]] ; then
		systemctl stop tomcat
	else
		service tomcat stop
	fi
}

function wait_for {
	while ! grep "Server startup in" $1/logs/catalina.out ; do
		log "Waiting for $1 to start"
		sleep 3
	done
}

function toggle_tomcat {
	start_tomcat
	wait_for $MANAGER
	wait_for $BPEL
	stop_tomcat
}

source <(curl -sSL http://downloads.lappsgrid.org/scripts/sniff.sh)

if [[ -z $OS ]] ; then
	log "The variable OS has not been set!"
	exit 1
fi

cp tomcat-users.xml $TOMCAT_MANAGER/conf
cp service_manager.xml $TOMCAT_MANAGER/conf/Catalina/localhost

cp tomcat-users-bpel.xml $TOMCAT_BPEL/conf/tomcat-users.xml
cp active-bpel.xml $TOMCAT_BPEL/conf/Catalina/localhost
cp langrid.ae.properties $TOMCAT_BPEL/bpr

# Get the new .war file before starting Tomcat for the first time.
log "Downloading the latest service manager war file."
wget https://github.com`wget -qO- https://github.com/openlangrid/langrid/releases/latest | grep --color=never \.war\" | cut -d '"' -f 2 `
mv `ls *.war | head -1` $TOMCAT_MANAGER/webapps/service_manager.war

toggle_tomcat

log "Creating indices."
wget $MANAGER/create_indices.sql
cat create_indices.sql | sudo -u postgres psql $DATABASE

log "Creating stored procedure."
wget $MANAGER/create_storedproc.sql
cat create_storedproc.sql | sudo -u postgres psql $DATABASE 

# We need to generate this on the fly since it include the user
# defined ROLENAME.
log "Changing owner of the stored procedure."
echo "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME" > alter.sql
cat alter.sql | sudo -u postgres psql $DATABASE

log "Securing the Tomcat installations"
for dir in $TOMCAT_MANAGER $TOMCAT_BPEL ; do
	pushd $dir > /dev/null
	# Make the tomcat user the owner of everything.
	chown -R tomcat:tomcat .

	# Tighten permissions on subdirectories.
	chmod -R 0700 bin
	chmod -R 0700 conf
	chmod -R 0750 logs
	chmod -R 0700 temp
	chmod -R 0700 work
	chmod -R 0770 webapps
	popd > /dev/null
done

#log "Removing default webapps."
#for dir in $TOMCAT_MANAGER/webapps $TOMCAT_BPEL/webapps ; do
#	pushd $dir > /dev/null
#	rm -rf docs examples manager host-manager
#	popd > /dev/null
#done

if [[ $OS = redhat7 || $OS = centos ]] ; then
	log "Opening port 8080"
	iptables -I INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
fi

start_tomcat 

log "The Service Grid is now running."
echo
