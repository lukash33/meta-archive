#!/bin/bash

## Tune parameters below and run this file from the command line.
## You may comment out parameters.
## Building image can take more than 30 minutes.
## Browser starts at the end of the process 

##################################################################

# image/container name:
	ma=${1:-meta-archive}
# browser port (local):
	http_port=8080
# oracle port (1521):
	oracle_port=1521
# Directory where images stored:  
	MA_DATA=/media
# Automatically import data right after build. Leave empty to not to import:
#	MA_IMPORT=YES
# All passwords template :)
	PASSWORD=secret
# Timezone (UTC):
	TIMEZONE=Europe/Moscow
# Cleanup before building. Leave empty to not to cleanup. Cleanup removes previously built container/image:
	CLEANUP=YES
# Build demo seed data? Leave empty if you want starting from scratch: 
	MA_DEMO=YES
# Try to start browser at the end of the build process:
	RUN_BROWSER=YES
# Proxy. If you are using network proxy. Set proxy for the build process and scripts inside container:
#	PROXY=http://172.17.0.1:7777/

##################################################################
# End parameters section. No need to change anything below this line.
##################################################################

date
echo "imgname=$ms; webport=$http_port; dir=$MA_DATA; importflag=$MA_IMPORT; password=$PASSWORD; timezone=$TIMEZONE; cleanup=$CLEANUP; demo=$MA_DEMO; runbrowser=$RUN_BROWSER; proxy=$PROXY"




##################################################################
##################################################################
## Build process starts here:

# cleanup:
[ "zero$CLEANUP" = "zero" ] || (docker stop $ma; docker rm -f $ma; docker rmi $ma)

# prepare docker command and arguments:
proxy="--build-arg http_proxy=$PROXY"; [ "zero$PROXY" = "zero" ] && proxy="" 
data="--build-arg MA_DATA=$MA_DATA"; [ "zero$MA_DATA" = "zero" ] && data="" 
import="--build-arg MA_IMPORT=$MA_IMPORT"; [ "zero$MA_IMPORT" = "zero" ] && import="" 

cmd="docker build $proxy $data $import --build-arg PASSWORD=$PASSWORD --build-arg TIMEZONE=$TIMEZONE --build-arg MA_DEMO=$MA_DEMO --tag $ma ."

echo "Starting build process. Depending on your hardware and Internet connection building may take more than 30 minutes..."
echo "Executing: $cmd ..."
time bash -c "$cmd"

##################################################################
[ "zero$RUN_BROWSER$MA_IMPORT" = "zero" ] && echo "Now you can 'docker run $ma' with appropriate parameters manually" 
[ "zero$RUN_BROWSER$MA_IMPORT" = "zero" ] && exit 0 
##################################################################

echo "Build process ends. You may find script and logs at $ma:/meta-archive"
##################################################################
##################################################################




echo "Launching $ma container..."
docker run -d --name $ma --shm-size=1g -v $MA_DATA:/$MA_DATA -p $http_port:8080 -p $oracle_port:1521 $ma
date
echo "Wait for ORACLE to start...";
sleep 10; 
docker exec $ma bash -c "flock /tmp/StartingOracle echo 'Oracle started'"
date
sleep 10; 

##################################################################
[ "zero$MA_IMPORT" = "zero" ] || (echo "Importing user data from $MA_DATA..."; docker exec $ma bash -c "http_proxy=$PROXY /meta-archive/script04.sh 2>&1 | tee /meta-archive/script04.sh.log") 
##################################################################

##################################################################
[ "zero$RUN_BROWSER" = "zero" ] && echo "Now you can 'docker run $ma' with appropriate parameters manually" 
[ "zero$RUN_BROWSER" = "zero" ] && exit 0 
##################################################################

##################################################################
# Run browser
##################################################################
ma_url="http://127.0.0.1:$http_port/apex/f?p=101:1"
echo "Launch browser on $ma_url..."
firefox_cmd=`which firefox`
chrome_cmd=`which google-chrome`

browser=$firefox_cmd
[ "zero$browser" = "zero" ] && browser=$chrome_cmd
[ "zero$browser" = "zero" ] && echo "No browser found"

exec $browser "$ma_url"

