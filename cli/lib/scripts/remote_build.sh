#
# build folder (build the server)
# /build
#   /<project>
#     /<project>_server
#   /oobium
#     /oobium
#     /oobium
#
# host folder (run the server)
# /host
#   /<project>
#     /tmp (certbot)
#     /www
#       /assets
#     /server.bin
#

address="<address>"
project="<project>"

echo cleaning...
rm -rf build

echo copying...
mkdir -p build/$project/${project}_server/env
mkdir -p build/oobium
cp pubspec.* build/$project/${project}_server
cp env/server-prod.json build/$project/${project}_server/env/server.json
cp -R lib build/$project/${project}_server
cp -R ../../oobium/oobium build/oobium/oobium

echo uploading...
rsync -rP build/ root@$address:~/build/ --delete

echo building remote...
ssh root@$address << EOF

  mkdir -p ~/host/$project/lib
  cd ~/build/$project/${project}_server || exit
  dart pub get

  echo generating...
  rm ~/host/$project/lib/server.bin
  dart2native lib/server.dart -o ~/host/$project/lib/server.bin
  cp -r ~/build/$project/${project}_server/env ~/host/$project
  rm -rf ~/host/$project/lib/www/assets
  mkdir -p ~/host/$project/lib/www/assets
  cp -r lib/www/assets ~/host/$project/lib/www
  cp -r lib/www-app ~/host/$project/lib

  pm2 restart $project || pm2 start ~/host/$project/lib/server.bin --name $project --cwd ~/host/$project

  echo done.
EOF
