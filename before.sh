#!/usr/bin/env bash
set -u

export SMG=smg-1.1.0-SNAPSHOT
#manager=http://downloads.lappsgrid.org/service-manager
export MANAGER=https://raw.githubusercontent.com/lappsgrid-incubator/service-manager-installation/17-centos-start
export SCRIPTS=http://downloads.lappsgrid.org/scripts

# Locations that Tomcat is installed.
TOMCAT_MANAGER=/usr/share/tomcat/service-manager
TOMCAT_BPEL=/usr/share/tomcat/active-bpel

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
	wait_for $TOMCAT_MANAGER
	wait_for $TOMCAT_BPEL
	stop_tomcat
	sleep 5
}

source <(curl -sSL http://downloads.lappsgrid.org/scripts/sniff.sh)

if [[ -z $OS ]] ; then
	log "The variable OS has not been set!"
	exit 1
fi

if [[ $OS = ubuntu ]] ; then
	log "Updating apt-get indices."
	apt-get update && apt-get upgrade -y
elif [[ $OS = redhat || $OS = centos ]] ; then
	yum makecache fast
else
	log "Unsupport Linux flavor: $OS"
	exit 1
fi

set +u
if [[ -z "$EDITOR" ]] ; then
	EDITOR=emacs
fi
set -eu

# Installs the packages required to install and run the Service Grid.
log "Installing common packages"
curl -sSL $SCRIPTS/install-common.sh | bash

# Edit the properties file to get it out of the way and allow then
# rest of the script to continue uninterrupted.
log "Configuring the Service Manager"
if [[ ! -e service-manager.properties ]] ; then
	wget $MANAGER/service-manager.properties
fi
$EDITOR service-manager.properties

log "Installing Java"
curl -sSL $SCRIPTS/install-java.sh | bash
log "Installing PostgreSQL"
curl -sSL $SCRIPTS/install-postgres.sh | bash

if [[ $OS = centos || $OS = redhat7 ]] ; then
	hba=/var/lib/pgsql/9.6/data/pg_hba.conf
	rm $hba
	echo "local all all trust" > $hba
	echo "host all all 127.0.0.1/32 trust" >> $hba
	echo "host all all ::1/128 trust" >> $hba
	systemctl restart postgresql-9.6
fi

if [ ! -e ServiceManager.config ] ; then
	wget $MANAGER/ServiceManager.config
fi

# Get the program used to transform the ServiceManager.config file
# into the various xml files.
wget http://downloads.lappsgrid.org/$SMG.tgz
tar xzf $SMG.tgz
chmod +x $SMG/smg

# Processing the ServiceManager.config will generate:
# 	service_manager.xml
# 	active-bpel.xml
# 	tomcat-users.xml
# 	tomcat-users-bpel.xml
# 	langrid.ae.properties
# 	db.config
$SMG/smg ServiceManager.config
source db.config

sudo -u postgres createuser -S -D -R $ROLENAME
sudo -u postgres psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
sudo -u postgres createdb $DATABASE -O $ROLENAME -E 'UTF8'

# Now install Tomcat and create the PostgreSQL database.
log "Starting Tomcat installation."
curl -sSL $MANAGER/install-tomcat.sh | bash

