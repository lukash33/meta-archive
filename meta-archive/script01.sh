#!/bin/bash

env

cat < /usr/share/zoneinfo/$TIMEZONE > /etc/localtime
# OPENCV lib does not work without this device:
ln /dev/null /dev/raw1394

apt-get update;
# apt-get -y upgrade;
# Perl module Image::Magick might not be installed easy. 
# Instead do # apt-get install perlmagic
apt-get install -y ed make cpanminus gcc libpuzzle-dev perlmagick libopencv-dev imagemagick ufraw ufraw-batch perlmagick
apt-get install -y libgeo-coder-googlev3-perl
# apt-get autoclean; apt-get clean; apt-get purge; apt-get autoremove

cpanm HTTP::Status
cpanm URI::URL
cpanm LWP::Simple
cpanm --force Module::Compile
cpanm Image::ExifTool Image::Libpuzzle Digest::MD5 Image::ObjectDetect File::Slurp Graphics::ColorObject DBI DBD::Oracle
cpanm PDL::LiteF PDL::Graphics::ColorDistance
cpanm Geo::Distance
cpanm Geo::Coder::Googlev3

# Bug #65700 for Graphics-ColorObject: Use of uninitialized value within @_ in lc with perl 5.12
# https://rt.cpan.org/Public/Bug/Display.html?id=65700
patch -l /usr/local/share/perl/5.18.2/Graphics/ColorObject.pm < patch-ColorObject.pm.txt

ed /entrypoint.sh <<EOF
/tomcat start/
s/^/#/
a
# OPENCV lib will not not work without this device:
ln /dev/null /dev/raw1394
.
/ssh start/
s/^/#/
1
/sleep 1/
s/sleep 1/sleep 1000/
1
/oracle-xe start/
s/^/flock --close \/tmp\/StartingOracle /
w
q
EOF

[ "zero$http_proxy" = "zero" ] || ed /meta-archive/Import.pl <<EOF
/PROXYSTRING/
s,PROXYSTRING,$http_proxy,p
s/^#//p
w
q
EOF


