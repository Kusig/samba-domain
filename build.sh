#!/bin/bash

docker build --force-rm --no-cache --build-arg BUILD_STRING="$(date -u)" --build-arg BUILD_DATE="$(date +%d-%m-%Y)" --build-arg  BUILD_TIME="$(date +%H:%M:%S)" -t samba-image:latest .
#docker build --build-arg BUILD_STRING="$(date -u)" --build-arg BUILD_DATE="$(date +%d-%m-%Y)" --build-arg  BUILD_TIME="$(date +%H:%M:%S)" -t samba-image:latest .

docker run -d --privileged --name samba-container samba-image:latest

VERSION=$(sudo docker exec -ti samba-container samba-tool --version | tr -d '\r')

echo VERSION: $VERSION

docker stop samba-container

docker commit samba-container guentherm/samba-domain:latest

docker push guentherm/samba-domain:latest

docker tag guentherm/samba-domain:latest guentherm/samba-domain:$VERSION

docker push guentherm/samba-domain:$VERSION

docker rm samba-container

docker rmi samba-image
