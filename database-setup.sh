#!/usr/bin/env bash

source db.config

wget $manager/create_storedproc.sql
#chown postrgres:postgres create_storedproc.sql

#sudo -u postgres createuser -S -D -R $ROLENAME
#sudo -u postgres psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
#sudo -u postgres createdb $DATABASE -O $ROLENAME -E 'UTF8'
#sudo -u postgres createlang plpgsql $DATABASE
#sudo -u postgres psql $DATABASE < create_storedproc.sql
#sudo -u postgres psql $DATABASE -c "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME"

createuser -S -D -R $ROLENAME
psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
createdb $DATABASE -O $ROLENAME -E 'UTF8'
createlang plpgsql $DATABASE
psql $DATABASE < create_storedproc.sql
psql $DATABASE -c "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME"
