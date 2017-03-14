# Instead of Userguide

## Easy way:

Review **build.sh**, edit it as appropriate and then run it from the command line. 

## Hard way:

0. Install [Docker](https://www.docker.com/) for your platform and build the **meta-archive** (see BUILD.md) image.

1. Run the Docker image using options:
```
	docker run -d --name meta-archive -v /MyArchive:/Shots --shm-size=1g -p 8080:8080 -p 1521:1521 meta-archive
```
where /MyArchive is the directory path where you keep your photos (or a portion of
them). Wait a few moments till ORACLE starts up and http://localhost:8080/apex/f?p=101 becomes available.

2. Get docker container commandline and import your photos:
```
	$ docker exec -u oracle -it meta-archive bash
	$ find /Shots | /meta-archive/Import.pl --debug=3 --threads=2
```
(It takes time!)

More import options shown in the Import.pl script itself.

3. Navigate your browser to http://localhost:8080/apex/f?p=101 to browse database and search photos

