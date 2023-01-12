#!/bin/bash

if [ $# -ne 1 ]; then
	echo "Usage: install.sh <HOSTNAME>"
	exit 1
fi

echo "Installing docker and docker-compose"
apt update && apt install docker docker-compose jq unzip -y

HOSTNAME="$1"
HOSTNAME_ENV=$(grep HOSTNAME .env | awk -F '=' '{printf $2}')

CONTAINERS=$(docker ps | grep "_${HOSTNAME}")
CONTAINERS_ENV=$(docker ps | grep "_${HOSTNAME_ENV}")

if [[ $CONTAINERS != "" ]]; then
  echo "Rapidpro containers are already running with provided hostname: ${HOSTNAME}" 
  exit 1
fi

if [[ $CONTAINERS_ENV != "" ]]; then
  echo "Rapidpro containers are already running with current hostname in .env: ${HOSTNAME_ENV}" 
  exit 1
fi

echo "Setting hostname: $HOSTNAME"
sed -i "s/$HOSTNAME_ENV/$HOSTNAME/g" ./rapidpro-docker/settings.py ./rapidpro-docker/settings_common.py ./rapidpro-docker/stack/startup.sh .env ./docker-compose.yml

echo "Building and creating docker containers"
if ! docker-compose up --build -d; then
  errout "Failed docker-compose" 1>&2
fi

echo "Installing NodeJS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt update && apt install nodejs -y
echo "Installing PM2..."
npm install pm2@latest -g
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u root --hp /opt

echo "Successfully installed rapidpro. Create superuser executing ./createsuperuser.sh"
