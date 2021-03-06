#!/usr/bin/env bash
set -u

# A setup script that assumes that Postgres and Java 8
# have already been installed on the instance.

smg=smg-1.1.0-SNAPSHOT
manager=http://downloads.lappsgrid.org/service-manager
scripts=http://downloads.lappsgrid.org/scripts

function usage()
{
	echo
	echo "USAGE"
	echo "   sudo ./simple-setup.sh [--secure]"
	echo
	echo "If the --secure option is specifed the default Tomcat webapps"
	echo "(manager, host-manager, etc) will be removed."
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

# Edit the properties file to get it out of the way and allow then
# rest of the script to continue uninterrupted.
if [[ ! -e service-manager.properties ]] ; then
	wget $manager/service-manager.properties
fi
$EDITOR service-manager.properties

# Edit the Service Manager config file. The config file is used
# to generate then Tomcat config files.
log "Configuring the Service Manager"
if [ ! -e ServiceManager.config ] ; then
	wget $manager/ServiceManager.config
fi
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

source ./db.config

log "Creating role, database and stored procedure."
wget $manager/create_storedproc.sql
wget $manager/create_indices.sql
wget $manager/database-setup.sh
echo '#!/usr/bin/env bash' | cat - db.config database-setup.sh > /tmp/database-setup.sh
chmod +x /tmp/database-setup.sh
mv *.sql /tmp
su - postgres -c "bash /tmp/database-setup.sh"

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

if [[ $OS = redhat7 ]] ; then
	systemctl start tomcat
else
	service tomcat start
fi

log "The Service Grid is now running."
echo
