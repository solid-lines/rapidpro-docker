# rapidpro-docker-compose

Run: ./install.sh \<HOSTNAME\>

1. Update server
2. Add the given \<HOSTNAME\> to the configuration files
3. Build and create docker containers
4. Update Nginx configuration files
  
To create a superuser run: ./createsuperuser.sh


![docker-compose-rapidpro yml](https://user-images.githubusercontent.com/48926694/193571380-2396d509-ab28-412c-b386-c2f5ee526cec.png)

## .env file settings
### Set up the facebook channel
* FACEBOOK_APPLICATION_ID
* FACEBOOK_APPLICATION_SECRET
* FACEBOOK_WEBHOOK_SECRET
### Allow/Not Allow sign up
* ALLOW_SIGNUPS=True/False

