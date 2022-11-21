# rapidpro-docker-compose
All the commands are assuming that the target installation folder for RapidPro is `/opt/rapidpro'

## Install RapidPro docker containers
1. `cd /opt`
2. `git clone https://github.com/solid-lines/rapidpro.git`
3. `cd /opt/rapidpro`
4. You can modify the environment variables used by rapidpro containers by editing the .env file
5. `./install.sh HOSTNAME`
6. It will take some minutes to complete the installation
7. Verify that the URL https://HOSTNAME is available
8. You can create a superuser running the script `./createsuperuser.sh`


Run: `./install.sh \<HOSTNAME\>`

1. Update server
2. Add the given `\<HOSTNAME\>` to the configuration files
3. Build and create docker containers
4. Update Nginx configuration files

## Uninstall Rapidpro docker containers
1. `cd /opt/rapidpro`
2. `./uninstall.sh`

## Modify Rapidpro docker containers
1. `cd /opt/rapidpro`
2. Modify the environment variables used by RapidPro containers by editing the .env file
3. `./restart_containers.sh`


![docker-compose-rapidpro yml](https://user-images.githubusercontent.com/48926694/193571380-2396d509-ab28-412c-b386-c2f5ee526cec.png)

## .env file settings
### Set up the facebook channel
* FACEBOOK_APPLICATION_ID
* FACEBOOK_APPLICATION_SECRET
* FACEBOOK_WEBHOOK_SECRET
### Allow/Not Allow sign up
* ALLOW_SIGNUPS=True/False

