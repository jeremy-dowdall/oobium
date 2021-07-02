
address="<address>"

ssh root@$address << EOF
  sudo apt-get update

  # install dart
  sudo apt-get install apt-transport-https
  sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
  sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'

  sudo apt-get update
  sudo apt-get install dart

  export PATH="$PATH:/usr/lib/dart/bin"
  echo 'export PATH="$PATH:/usr/lib/dart/bin"' >> ~/.profile

  dart --version
EOF
