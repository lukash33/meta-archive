The *MetaArchive* software project is intended to help searching photo in a large
private digital archive.

* [Live Demo](http://37.139.9.192/apex/f?p=101).
* [Video demo](https://youtu.be/JMDMsKdvT30)

*MetaArchive* is targeted to lazy experienced photo-amateurs and professionals
who find *GooglePhoto* and *LightRoom* (and the like) Ok but still face difficulties searching a single photo
in their archive.

**I can recall this beautiful shot I've made a few years ago. I even recall how it looks like, but
have no idea of where I put the original RAW file. Which disk? Which directory? Which path? *MetaArchive* answers.**

## Short howto for impatients: 
	Review, modify and run `./build.sh` from the commandline. Also see USER.md, BUILD.md.

## Basic principles of the *MetaArchive* software are:
 * it is free.
 * use ready-to-use software as much as possible
 * as lazy as possible; software should do everything

## Basic features are:
 * it is for personal home use only
 * easy browser interface to the application
 * multiplatform
 * process RAWs and JPEGs
 * store no originals but small previews along with metadata
 * process comparatively large (TBs) archives, incremental processing possible

## Search capabilities:
 * search by narrowing down flexible set of criterias
 * associative search capabilities
 * search by major colors
 * search images by similarity
 * search for duplicates
 * search by common image properties like size, portrait/landscape, saturation, brightness, etc
 * search by common EXIF metadata like date/time of the shot, GPS coordinates, camera, lens, etc
 * search by number of faces recognized
 * search by street address


## Comparision:

*GooglePhoto* is Ok but **MetaArchive** is different - it is personal, completely free of charge 
and does not require uploading your personal sensitive data to a cloud.

*LightRoom* is Ok but **MetaArchive** is different - software goal is different, it is free of charge, 
it requires no image tags, it is multiplatform and its search criterias are different.

## System Requirements:

64-bit OS with Docker installed. 2gb RAM or more. Some 20 gb of disk space for docker images/containers or more. 
30-60 minutes to download&build docker image. 1-2 seconds per photo to import.
