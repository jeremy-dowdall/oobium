
project="<project>"
address="<address>"
host="<host>"

ssh root@$address << EOF
#  mkdir -p /root/$project/certbot
#  certbot certonly --webroot -d $host -w /root/$project/certbot
  certbot certonly -d $host --standalone -n
#  certbot renew
EOF
