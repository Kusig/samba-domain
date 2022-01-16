#!/bin/bash
mkdir $(pwd)/tmp

docker build --force-rm --no-cache --build-arg BUILD_STRING="$(date -u)" --build-arg BUILD_DATE="$(date +%d-%m-%Y)" --build-arg  BUILD_TIME="$(date +%H:%M:%S)" -t samba-image:latest .
#docker build --build-arg BUILD_STRING="$(date -u)" --build-arg BUILD_DATE="$(date +%d-%m-%Y)" --build-arg  BUILD_TIME="$(date +%H:%M:%S)" -t samba-image:latest .

# now we must evaluate the samba version by starting the just created container shortly
docker run -d -e "DOMAINPASS=ThisIsMy_2_AdminPassword" -v $(pwd)/tmp:/var/lib/samba	-v $(pwd)/tmp:/etc/samba/external --privileged --name samba-version-container samba-image:latest
VERSION=$(sudo docker exec -ti samba-version-container smbd --version | sed -n -e 's/^.*Version //p'| tr -d '\r' )
echo Detected Samba Version: $VERSION
docker stop samba-version-container
docker rm samba-version-container

# tag the already pushed image properly with the just evaluated samba version
docker tag samba-image:latest guentherm/samba-domain:$VERSION
docker push guentherm/samba-domain:$VERSION
docker push guentherm/samba-domain:latest

# clean up
docker rmi samba-image:latest