# How to buld

Note: **script01.sh** downloads a lot of (several gigs) payload to enable image processing capabilities of basic Ubuntu image.

Download and building image takes about 30mins.

`
ma=meta-archive		# name of the image
http_port=8080		# browser port
oracle_port=1521	# oracle port
data=/Shots		# where your photos are

PASSWORD=secret		# passwords
TIMEZONE=Europe/Moscow	# your timezone

docker stop $ma		# cleanup
docker rm -f $ma	# cleanup
docker rmi $ma		# cleanup
time docker build --build-arg PASSWORD=$PASSWORD --build-arg TIMEZONE=$TIMEZONE --tag $ma .
docker run -d --name $ma -v $data:$data --shm-size=1g -p $http_port:8080 -p $oracle_port:1521 $ma
docker exec -it $ma bash
`
