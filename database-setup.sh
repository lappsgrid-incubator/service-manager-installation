#!/usr/bin/env bash

source ./db.config

echo "Creating role, database and stored procedure."
service postgresql start
wget $manager/create_storedproc.sql
until pg_isready ; do 
	echo "Waiting for PostgreSQL service to start"
	sleep 2
done
createuser -S -D -R $ROLENAME
psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
createdb $DATABASE -O $ROLENAME -E 'UTF8'
createlang plpgsql $DATABASE
psql $DATABASE < create_storedproc.sql
psql $DATABASE -c "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME"
