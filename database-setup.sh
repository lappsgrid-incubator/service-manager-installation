createuser -S -D -R $ROLENAME
psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
createdb $DATABASE -O $ROLENAME -E 'UTF8'
#createlang plpgsql $DATABASE
psql $DATABASE < /tmp/create_indices.sql
psql $DATABASE < /tmp/create_storedproc.sql
echo "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME" > /tmp/alter.sql
psql $DATABSE < /tmp/alter.sql
#psql $DATABASE -c "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME"
