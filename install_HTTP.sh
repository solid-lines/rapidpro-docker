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
#large_client_header_buffers 2 1k;
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
        cat <<EOF > /etc/nginx/upstream/rapidpro.conf
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
                  proxy_pass http://127.0.0.1:8090;
                  break;
                }

                # all courier URLs go to courier
                location ^~ /c/ {
                  proxy_set_header Host \$http_host;
                  proxy_pass http://127.0.0.1:8081;
                  break;
                }

                location /sitestatic/ {
                  root  $(pwd)/data;
                  expires  max;
            }

                listen 80;
          }
EOF
}

# Send error output and exit with status code 1
function errout {
  echo "ERROR: $*, exiting..." >&2
  echo "========================================================="
  docker-compose down
  sed -i 's/$HOSTNAME/HOST_NAME/g' ./rapidpro-docker/settings.py ./rapidpro-docker/settings_common.py .env
  rm -rf /etc/nginx/upstream/rapidpro.conf
  exit 1
}

if [ $# -ne 1 ]; then
        echo "Usage: install.sh <HOSTNAME>"
        exit 1
fi

HOSTNAME="$1"
echo "Installing docker and docker-compose..."
apt update && apt install docker docker-compose jq unzip sendmail -y
if [ ! -f .env ]
then
    cp sample.env .env
fi

echo "Setting hostname: $HOSTNAME ..."
sed -i "s/HOST_NAME/$HOSTNAME/g" ./rapidpro-docker/settings.py ./rapidpro-docker/settings_common.py .env

echo "Building and creating docker containers..."
if ! docker-compose up --build -d; then
  errout "Failed docker-compose" 1>&2
fi

echo "Configuring Nginx..."
if ! which nginx 1>/dev/null; then
  apt update && apt install nginx -y
  install_nginx
  install_upstream
else
  install_upstream
fi
service nginx start

echo "Installing NodeJS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt update && apt install nodejs -y
echo "Installing PM2..."
npm install pm2@latest -g
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u root --hp /opt

echo "Successfully installed rapidpro. Create superuser executing ./createsuperuser.sh"
