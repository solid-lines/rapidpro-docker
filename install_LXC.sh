#!/bin/bash

function install_nginx {
cat <<EOF > /etc/nginx/nginx.conf
	user   www-data;
	worker_processes  auto;

	error_log  /var/log/nginx/error.log info;
	pid        /var/run/nginx.pid;

	events {
		worker_connections  1024;
	}

	http {
	  include       mime.types;
	  default_type  application/octet-stream;

	  log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
						'\$status $body_bytes_sent "\$http_referer" '
						'"\$http_user_agent" "\$http_x_forwarded_for"';
	  access_log  /var/log/nginx/access.log  main;

	  # Include separate files in the main "http{}" configuration
	  include  conf.d/*.conf;

	  # Allow status requests from localhost
	  server
	  {
		listen 127.0.0.1;
		server_name localhost;

		location /nginx_status {
		  stub_status on; # activate stub_status module
		  access_log off;
		  allow 127.0.0.1; # localhost
		  allow ::1; # localhost
		  deny all;
		}
	  }

	  include upstream/*.conf;
	}
EOF

cat <<EOF > /etc/nginx/conf.d/performance.conf
sendfile              on;
tcp_nopush            on;
tcp_nodelay           on;
keepalive_timeout     10;
send_timeout 10;
types_hash_max_size   2048;
client_max_body_size  20M;
client_body_timeout 10; 
client_header_timeout 10;
large_client_header_buffers 2 1k;
EOF

cat <<EOF > /etc/nginx/conf.d/gzip.conf
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
EOF

mkdir -p /etc/nginx/ssl
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
chmod 400 /etc/nginx/ssl/dhparam.pem

cat <<EOF > /etc/nginx/conf.d/ssl.conf
# Diffie-Hellman parameters
ssl_dhparam /etc/nginx/ssl/dhparam.pem;

# SSL settings
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;

ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
  
ssl_session_cache shared:SSL:20m;
ssl_session_timeout 20m;
ssl_session_tickets off;

# SSL OCSP stapling
ssl_stapling         on;
ssl_stapling_verify  on;

# DNS resolver configuration for OCSP response
resolver          8.8.4.4 8.8.8.8 valid=300s ipv6=off;
resolver_timeout  10s;
EOF

cat <<EOF > /etc/nginx/conf.d/security.conf
# Hide nginx server version
server_tokens off;
EOF

}

function install_upstream {
	mkdir -p /etc/nginx/upstream
	cat <<EOF > /etc/nginx/upstream/$HOSTNAME.conf
	  server {
		server_name  $HOSTNAME;
		location / {
		  proxy_pass        http://localhost:8000;
	      proxy_set_header   Host \$host;
		  proxy_set_header   X-Real-IP \$remote_addr;
		  proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
		  proxy_set_header   X-Forwarded-Host \$server_name;
		}

		# all Mailroom URLs go to Mailroom
		location ^~ /mr/ {
		  proxy_set_header Host \$http_host;
		  proxy_pass http://localhost:8090;
		  break;
		}

		# all courier URLs go to courier
		location ^~ /c/ {
		  proxy_set_header Host \$http_host;
		  proxy_pass http://localhost:8081;
		  break;
		}

		location /sitestatic/ {
		  root  $(pwd)/data;
		  expires  max;
	    }

		listen 443 ssl; # managed by Certbot
		ssl_certificate /etc/letsencrypt/live/$HOSTNAME/fullchain.pem;
		ssl_certificate_key /etc/letsencrypt/live/$HOSTNAME/privkey.pem;
	  }


	  server {
		if (\$host = $HOSTNAME) {
			return 301 https://\$host\$request_uri;
		} 


		server_name  $HOSTNAME;

	    listen 80;
		return 404;
	  }
EOF

CONTAINERS=$(lxc list -f json | jq -r '.[] | select((.status=="Running") and (.config."user.type"=="Tomcat server")) |.name')

cat <<EOF > /etc/nginx/upstream/$HOST_CONTAINER.conf
server {
	if (\$host = $HOST_CONTAINER) {
		return 301 https://\$host\$request_uri;
	}

	server_name  $HOST_CONTAINER;

	listen 80;
	return 404;
}

server {
	server_name  $HOST_CONTAINER;
EOF
for CONTAINER in $CONTAINERS; do
lxc exec ${CONTAINER} -- ufw allow 8080/tcp
lxc exec ${CONTAINER} -- ufw reload
IP=$(lxc list | grep " "$CONTAINER" " | awk '{print $6}')
cat <<EOF >> /etc/nginx/upstream/$HOST_CONTAINER.conf
	location /${CONTAINER} {
		proxy_pass http://${IP}:8080/${CONTAINER};
		proxy_redirect            off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto  \$scheme;
		proxy_hide_header X-Frame-Options;
		proxy_hide_header Strict-Transport-Security;
		proxy_hide_header X-Content-Type-Options;
		proxy_hide_header X-XSS-protection;
		proxy_hide_header X-Powered-By;
		proxy_hide_header Server;

		proxy_connect_timeout  480s;
		proxy_read_timeout     480s;
		proxy_send_timeout     480s;

		proxy_buffer_size        128k;
		proxy_buffers            8 128k;
		proxy_busy_buffers_size  256k;
	}

	location /${CONTAINER}-glowroot {
		proxy_pass http://${IP}:4000/${CONTAINER}-glowroot;
		proxy_redirect            off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto  \$scheme;
		proxy_hide_header X-Frame-Options;
		proxy_hide_header Strict-Transport-Security;
		proxy_hide_header X-Content-Type-Options;
		proxy_hide_header X-XSS-protection;
		proxy_hide_header X-Powered-By;
		proxy_hide_header Server;

		proxy_connect_timeout  480s;
		proxy_read_timeout     480s;
		proxy_send_timeout     480s;

		proxy_buffer_size        128k;
		proxy_buffers            8 128k;
		proxy_busy_buffers_size  256k;
	}
EOF
done
cat <<EOF >> /etc/nginx/upstream/$HOST_CONTAINER.conf
	listen 443 ssl; # managed by Certbot
	ssl_certificate /etc/letsencrypt/live/$HOST_CONTAINER/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$HOST_CONTAINER/privkey.pem;
}
EOF

}

# Send error output and exit with status code 1
function errout {
  echo "ERROR: $*, exiting..." >&2
  echo "========================================================="
  docker-compose down
  sed -i 's/$HOSTNAME/HOST_NAME/g' ./rapidpro-docker/settings.py ./rapidpro-docker/settings_common.py ./rapidpro-docker/stack/startup.sh .env ./docker-compose.yml
  rm -rf /etc/nginx/upstream/rapidpro.conf
  exit 1
}

if [ $# -ne 1 ]; then
	echo "Usage: install.sh <HOSTNAME>"
	exit 1
fi

HOSTNAME="$1"
echo "Installing docker and docker-compose"
apt update && apt install docker docker-compose jq unzip -y

echo "Setting hostname: $HOSTNAME"
sed -i "s/HOST_NAME/$HOSTNAME/g" ./rapidpro-docker/settings.py ./rapidpro-docker/settings_common.py ./rapidpro-docker/stack/startup.sh .env ./docker-compose.yml

echo "Building and creating docker containers"
if ! docker-compose up --build -d; then
  errout "Failed docker-compose" 1>&2
fi


# Remove NAT rule from UFW
yes | ufw reset
DATE=$(date '+%Y%m%d')
USERRULES=$(ls /etc/ufw/user.rules.${DATE}* | tail -1)
USER6RULES=$(ls /etc/ufw/user6.rules.${DATE}* | tail -1)
cp ${USERRULES} /etc/ufw/user.rules
cp ${USER6RULES} /etc/ufw/user6.rules
ufw disable && yes | ufw enable

HOST_CONTAINER=$(cd / && find . -name containers.json | grep dhis2-tools-ng | tail -1 | xargs cat | jq -r .fqdn)

echo "Configuring nginx"
if ! which nginx 1>/dev/null; then
  apt update && apt install nginx -y
  install_nginx
fi

if ! which certbot 1>/dev/null; then
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  service nginx stop
  if ! certbot certonly -d $HOSTNAME --standalone -m daniel.castelao@solidlines.io --agree-tos -n --no-eff-email; then
    errout "Failed when installing certificate"
  fi
  if ! certbot certonly -d $HOST_CONTAINER --standalone -m daniel.castelao@solidlines.io --agree-tos -n --no-eff-email; then
    errout "Failed when installing certificate"
  fi
  install_upstream
  service nginx start
else
  service nginx stop
  if ! certbot certonly -d $HOSTNAME --standalone -m daniel.castelao@solidlines.io --agree-tos -n --no-eff-email; then
    errout "Failed when installing certificate"
  fi
  if ! certbot certonly -d $HOST_CONTAINER --standalone -m daniel.castelao@solidlines.io --agree-tos -n --no-eff-email; then
    errout "Failed when installing certificate"
  fi
  install_upstream
  service nginx start
fi

echo "Installing NodeJS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt update && apt install nodejs -y
echo "Installing PM2..."
npm install pm2@latest -g
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u root --hp /opt

echo "Successfully installed rapidpro. Create superuser executing ./createsuperuser.sh"
