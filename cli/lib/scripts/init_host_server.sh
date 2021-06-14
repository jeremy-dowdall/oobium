
address="<address>"
host="<host>"
email="<email>"

ssh root@$address << EOF
  sudo apt-get update

  echo installing pm2... (for server monitoring / restarts)
  wget -qO- https://getpm2.com/install.sh | bash

  echo installing certbot... (for ssl)
  snap install core; snap refresh core
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot

  echo installing certificates / keys...
  certbot certonly -d $host -d www.$host --standalone -n --agree-tos --email $email
EOF