
address="<address>"
host="<host>"
email="<email>"

ssh root@$address << EOF
  echo updating certificates / keys...
  pm2 stop gmbc
  certbot certonly -d $host -d www.$host --standalone -n --agree-tos --email $email --expand
EOF
