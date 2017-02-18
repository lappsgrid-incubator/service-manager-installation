#!/usr/bin/env bash

psql $DATABASE < /tmp/create_indices.sql
psql $DATABASE < /tmp/create_storedproc.sql
echo "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME" > /tmp/alter.sql
#psql $DATABSE < /tmp/alter.sql
cat /tmp/alter.sql | psql -U postgres $DATABASE

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

if [[ $OS = redhat7 ]] ; then
	systemctl start tomcat
else
	service tomcat start
fi

log "The Service Grid is now running."
echo
