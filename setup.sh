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
	echo $1 | tee /var/log/service-manager-install.log >&2
}

function start_tomcat {
	if [[ $OS = redhat7 || $OS = centos]] ; then
		systemctl start tomcat
	else
		service tomcat start
	fi
}

function stop_tomcat {
	if [[ $OS = redhat7 || $OS = centos]] ; then
		systemctl stop tomcat
	else
		service tomcat stop
	fi
}

function wait_for {
	while ! grep "Server startup in" $1/log/catalina.out ; do
		echo "Waiting for $1 to start"
		sleep 1
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

if [[ $OS = centos || $OS = redhat7 ]] ; then
	hba=/var/lib/pgsql/9.6/data/pg_hba.conf
	rm $hba
	echo "local all all trust" > $hba
	echo "host all all 127.0.0.1/32 trust" >> $hba
	echo "host all all ::1/128 trust" >> $hba
	systemctl restart postgresql-9.6
fi

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
source db.config

sudo -u postgres createuser -S -D -R $ROLENAME
sudo -u postgres psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
sudo -u postgres createdb $DATABASE -O $ROLENAME -E 'UTF8'

# Now install Tomcat and create the PostgreSQL database.
log "Starting Tomcat installation."
curl -sSL $manager/install-tomcat.sh | bash

cp tomcat-users.xml $MANAGER/conf
cp service_manager.xml $MANAGER/conf/Catalina/localhost

cp tomcat-users-bpel.xml $BPEL/conf/tomcat-users.xml
cp active-bpel.xml $BPEL/conf/Catalina/localhost
cp langrid.ae.properties $BPEL/bpr

toggle_tomcat

log "Creating indices and stored procedure."
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

#createlang plpgsql $DATABASE
sudo -u postgres psql $DATABASE < /tmp/create_indices.sql
sudo -u postgres psql $DATABASE < /tmp/create_storedproc.sql
echo "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME" > /tmp/alter.sql
#psql $DATABSE < /tmp/alter.sql
cat /tmp/alter.sql | sudo -u postgres psql $DATABASE

#psql $DATABASE -c "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME"

log "Securing the Tomcat installations"
for dir in $MANAGER $BPEL ; do
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

log "Downloading the latest service manager war file."
wget https://github.com`wget -qO- https://github.com/openlangrid/langrid/releases/latest | grep --color=never \.war\" | cut -d '"' -f 2 `
mv `ls *.war | head -1` $MANAGER/webapps/service_manager.war

log "Removing default webapps."
for dir in $MANAGER/webapps $BPEL/webapps ; do
	pushd $dir > /dev/null
	rm -rf docs examples manager host-manager
	popd > /dev/null
done

#if [[ $OS = redhat7 ]] ; then
#	systemctl start tomcat
#else
#	service tomcat start
#fi

start_tomcat 

log "The Service Grid is now running."
echo
