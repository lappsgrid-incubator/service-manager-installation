#!/usr/bin/env bash
set -u

smg=smg-1.1.0-SNAPSHOT
manager=http://downloads.lappsgrid.org/service-manager
scripts=http://downloads.lappsgrid.org/scripts

function usage()
{
	echo
	echo "USAGE"
	echo "   sudo ./setup.sh"
	echo
	echo
}

function log {
	echo $1 | tee /var/log/service-manager-install.log >&2
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
curl -sSL $scripts/install-common.sh | bash

# Edit the properties file to get it out of the way and allow then
# rest of the script to continue uninterrupted.
log "Configuring the Service Manager"
if [[ ! -e service-manager.properties ]] ; then
	wget $manager/service-manager.properties
fi
$EDITOR service-manager.properties

log "Installing Java"
curl -sSL $scripts/install-java.sh | bash
log "Installing PostgreSQL"
curl -sSL $scripts/install-postgres.sh | bash

if [ ! -e ServiceManager.config ] ; then
	wget $manager/ServiceManager.config
fi

# Get the program used to transform the ServiceManager.config file
# into the various xml files.
wget http://downloads.lappsgrid.org/$smg.tgz
tar xzf $smg.tgz
chmod +x $smg/smg

# Processing the ServiceManager.config will generate:
# 	service_manager.xml
# 	active-bpel.xml
# 	tomcat-users.xml
# 	tomcat-users-bpel.xml
# 	langrid.ae.properties
# 	db.config
$smg/smg ServiceManager.config

# Now install Tomcat and create the PostgreSQL database.
log "Starting Tomcat installation."
MANAGER=/usr/share/tomcat/service-manager
BPEL=/usr/share/tomcat/active-bpel
curl -sSL $manager/install-tomcat.sh | bash

cp tomcat-users.xml $MANAGER/conf
cp service_manager.xml $MANAGER/conf/Catalina/localhost

cp tomcat-users-bpel.xml $BPEL/conf/tomcat-users.xml
cp active-bpel.xml $BPEL/conf/Catalina/localhost
cp langrid.ae.properties $BPEL/bpr

log "Creating role, database and stored procedure."
# Grab the SQL and setup scripts.
wget $manager/create_storedproc.sql
wget $manager/create_indices.sql
wget $manager/database-setup.sh

# Generate a custom database-setup.sh with the settings generated above.
#echo '#!/usr/bin/env bash' | cat - db.config database-setup.sh > /tmp/database-setup.sh
#chmod +x /tmp/database-setup.sh
#mv *.sql /tmp
# Now run the setup script as the postgres user.
#su - postgres -c "bash /tmp/database-setup.sh"
#rm /tmp/*.sql
createuser -U postgres -S -D -R $ROLENAME
psql -U postgres --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
createdb -U postgres $DATABASE -O $ROLENAME -E 'UTF8'
