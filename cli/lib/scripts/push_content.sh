address="<address>"
project="<project>"

rsync -rP --delete content/ root@$address:~/host/$project/content/
