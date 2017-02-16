#!/usr/bin/env bash

createuser -S -D -R $ROLENAME
psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
createdb $DATABASE -O $ROLENAME -E 'UTF8'
createlang plpgsql $DATABASE
psql $DATABASE < create_storedproc.sql
psql $DATABASE -c "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME"
