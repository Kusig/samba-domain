#!/bin/bash
mkdir $(pwd)/tmp

docker build --force-rm --no-cache --build-arg BUILD_STRING="$(date -u)" --build-arg BUILD_DATE="$(date +%d-%m-%Y)" --build-arg  BUILD_TIME="$(date +%H:%M:%S)" -t samba-image:latest .
#docker build --build-arg BUILD_STRING="$(date -u)" --build-arg BUILD_DATE="$(date +%d-%m-%Y)" --build-arg  BUILD_TIME="$(date +%H:%M:%S)" -t samba-image:latest .

docker run -d -e "DOMAINPASS=ThisIsMy_2_AdminPassword" -v $(pwd)/tmp:/var/lib/samba	-v $(pwd)/tmp:/etc/samba/external --privileged --name samba-container samba-image:latest

VERSION=$(sudo docker exec -ti samba-container smbd --version | sed -n -e 's/^.*Version //p'| tr -d '\r' )

echo Detected Samba Version: $VERSION

docker stop samba-container

docker commit samba-container guentherm/samba-domain:latest

docker push guentherm/samba-domain:latest

docker tag guentherm/samba-domain:latest guentherm/samba-domain:$VERSION

docker push guentherm/samba-domain:$VERSION

docker rm samba-container

docker rmi samba-image
