#!/bin/sh
set -ex # fail on any error & print commands as they're run

cp /rapidpro/env/static/*.* /rapidpro/env/sitestatic/*.*

if [ "x$MANAGEPY_COLLECTSTATIC" = "xon" ]; then
	/rapidpro/env/bin/python manage.py collectstatic --noinput --no-post-process
fi
if [ "x$CLEAR_COMPRESSOR_CACHE" = "xon" ]; then
	/rapidpro/env/bin/python clear-compressor-cache.py
fi
#if [ "x$MANAGEPY_COMPRESS" = "xon" ]; then
#	/rapidpro/env/bin/python manage.py compress --extension=".haml" --force -v0
#fi
/bin/bash -c 'source /rapidpro/env/bin/activate'
if [ "x$MANAGEPY_INIT_DB" = "xon" ]; then
	#/rapidpro/env/bin/python manage.py dbshell < init_db.sql
	psql -U postgres -h postgresql -tc "SELECT 1 FROM pg_user WHERE usename = 'temba'" | grep -q 1 || psql -U postgres -h postgresql -c "CREATE USER temba WITH SUPERUSER encrypted password 'temba'"
	psql -U postgres -h postgresql -tc "SELECT 1 FROM pg_database WHERE datname = 'temba'" | grep -q 1 || psql -U postgres -h postgresql -c "CREATE DATABASE temba WITH OWNER temba"
	psql -U postgres -h postgresql -c "ALTER DATABASE temba OWNER TO temba"
	psql -U postgres -h postgresql -d temba -c "CREATE EXTENSION IF NOT EXISTS postgis"
	psql -U postgres -h postgresql -d temba -c "CREATE EXTENSION IF NOT EXISTS hstore"
	psql -U postgres -h postgresql -d temba -c "CREATE EXTENSION IF NOT EXISTS postgis_topology"
	psql -U postgres -h postgresql -d temba -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'
fi
if [ "x$MANAGEPY_MIGRATE" = "xon" ]; then
	/rapidpro/env/bin/python manage.py migrate
fi
if [ "x$MANAGEPY_IMPORT_GEOJSON" = "xon" ]; then
	echo "Downloading geojson for relation_ids $OSM_RELATION_IDS"
	/rapidpro/env/bin/python manage.py download_geojson $OSM_RELATION_IDS
	/rapidpro/env/bin/python manage.py import_geojson ./geojson/*.json
	echo "Imported geojson for relation_ids $OSM_RELATION_IDS"
fi
$STARTUP_CMD 
#>> /var/log/rapidpro/rapidpro.log 2>>/var/log/rapidpro/rapidpro.error
