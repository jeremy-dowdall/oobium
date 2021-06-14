
project="<project>"
address="<address>"
host="<host>"

ssh root@$address << EOF
  echo installing certificates / keys...
  cp /etc/letsencrypt/live/$host-0001/fullchain.pem /etc/letsencrypt/live/$host/
  cp /etc/letsencrypt/live/$host-0001/privkey.pem /etc/letsencrypt/live/$host/
  pm2 start $project
EOF
