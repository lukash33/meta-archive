:
eval 'exec /usr/bin/perl -S $0 "$@"'
 if 0;
 
# Standalone multithreaded utility to import images from a directory tree to an Oracle database

# Usage: 
# find /Dir -type f | sort | Import.pl
# or
# Import.pl filename...

BEGIN {
$ENV{NLS_LANG}="AMERICAN_AMERICA.AL32UTF8";
$ENV{NLS_NUMERIC_CHARACTERS}=".";
$ENV{ORACLE_SID}="XE";
$ENV{PASSWORD} = "secret" if(!defined($ENV{PASSWORD})); # app schema password
undef $ENV{"http_proxy"};
#$ENV{"http_proxy"}="PROXYSTRING";
};

$|=1;

use strict;
use utf8;
use open qw(:std :utf8);
use Getopt::Long;
use DBI;
use DBD::Oracle qw(:ora_types);
use Image::ExifTool qw(:Public);
use Image::Libpuzzle;
use Digest::MD5  qw(md5_hex);
use IO::Pipe;
use File::Slurp;
use POSIX qw(_exit);
use File::Basename;
use File::Path; # mkpath, make_path
use Graphics::ColorObject; 
use Image::Magick;
use Image::ObjectDetect;
use PDL::LiteF; 
use PDL::Graphics::ColorDistance;
use Geo::Distance;
use Geo::Coder::Googlev3;
use URI::URL;
use LWP::Simple;
use HTTP::Status qw(:constants :is status_message);

my $cascade = '/usr/share/opencv/haarcascades/haarcascade_frontalface_alt2.xml';	# OpenCV library haar face template to use

my $opt_tmp="/dev/shm";		# where to put temp files
my $opt_threads=0;			# number of threads
my $opt_rewrite=0;			# replace duplicate records by PATH		
my $opt_md5_duplicates=1;
my $opt_max_img_size=6000; 	# max libpuzzle can do
my $opt_connect_string="MA/".$ENV{PASSWORD};		# Oracle connect string
my $opt_debug=4;			# debug printout level
my $opt_lambdas=6;			# Image::Libpuzzle precision;
my $opt_puzzle_len = ($opt_lambdas-2)**2*8 + ($opt_lambdas-2)*4*5 + 4*3;
#my $opt_puzzle_len=220;		# fixed length of the libpuzzle pattern (in bytes) = 220 for lambdas=6 -- see TRIGGER MA_FILL_PUZZLE_TRG for details and MA_DISTANCE function 
#my $opt_puzzle_len=544;	# fixed length of the libpuzzle pattern (in bytes) = 544 for lambdas=9
my $opt_thumb_size=150;		# image thumbnail size (stored as blob)
my $opt_preview_size=300;	# image preview size to analyze

# color match options:
my $opt_color_distance = 22;    # use palette color if distance to color less than $opt_color_distance  
my $opt_color_fraction = 0.20;  # fraction of pixels of the same color to be noticed 
my $opt_colors = 7;             # different colors to use to quantize
my $opt_color_match = "hsl";    # color distance algorithm to use, may be "hsl" or "lab"; hsl is fast and OK, lab is slower and gives strange results
my $opt_color_dirty=0.7;        # match dirty colors - how much (S)ATURATION and (L)IGHTNESS might differ from pure colors [0..1]

GetOptions(
   "debug=i" => \$opt_debug,
   "threads=i" => \$opt_threads,
   "max_img_size=i" => \$opt_max_img_size,
   "tmp=s" => \$opt_tmp,
   "rewrite!" => \$opt_rewrite, # allow duplicates by path, 
   "color-distance=i" => \$opt_color_distance,
   "color-fraction=f" => \$opt_color_fraction,
   "color-dirty=f" => \$opt_color_dirty,
   "colors=i" => \$opt_colors,
   "color-match=s" => \$opt_color_match,
);

# what props can be queried:
my @identify_props_thumb = qw(

	fx:mean
	fx:mean.r
	fx:mean.g
	fx:mean.b
	fx:mean.c
	fx:mean.m
	fx:mean.y
	entropy
	kurtosis
	mean
	skewness
	standard-deviation
	type
);

# what props to query:
my @identify_props_thumb = qw(
	mean
	type
);

my @valid_exif_props = (	# just skip other
	"EXIF::Camera Model Name",
	"EXIF::Flash",
	"EXIF::GPS Latitude",
	"EXIF::GPS Longitude",
	"EXIF::Lens ID",
	"EXIF::Image Height",
	"EXIF::Image Width",
	"EXIF::Megapixels",
	"EXIF::Orientation",
	"EXIF::Artist",
	"EXIF::Owner Name",
	"EXIF::Camera Temperature",
	"EXIF::MIME Type",
	"EXIF::File Type"
);

my @PropMap = # prop name, db column name, data type: N-number, V-varchar2
(
[ "IDENTIFY::mean",                  "MEAN",                                'N' ],
[ "EXIF::Image Height",              "HEIGHT",                              'N' ],
[ "EXIF::Image Width",               "WIDTH",                               'N' ],
[ "EXIF::Megapixels",                "MEGAPIXELS",                          'N' ],
[ "INT::AF NO of Points In Focus",   "POINTS_IN_FOCUS",                     'N' ],
[ "INT::Faces",                      "FACES",                               'N' ],
[ "INT::Saturation",                 "SATURATION",                          'N' ],
[ "EXIF::Camera Temperature",        "TEMPERATURE",                         'N' ],
[ "INT::Color1",					 "COLOR1",							  	'N' ],
[ "INT::ColorDistance1",			 "COLOR_DISTANCE1",					  	'N' ],
[ "INT::Color2",					 "COLOR2",							  	'N' ],
[ "INT::ColorDistance2",			 "COLOR_DISTANCE2",					  	'N' ],

[ "EXIF::Camera Model Name",         "CAMERA",                              'V' ],
[ "EXIF::Flash",                     "FLASH",                               'V' ],
[ "EXIF::Lens ID",                   "LENS",                                'V' ],
[ "EXIF::Orientation",               "ORIENTATION",                         'V' ],
[ "EXIF::Artist",                    "ARTIST",                              'V' ],
[ "EXIF::Owner Name",                "OWNER",                               'V' ],
[ "EXIF::MIME Type",                 "MIME_TYPE",                           'V' ],
[ "EXIF::File Type",                 "EXIF_FILE_TYPE",                      'V' ],
[ "IDENTIFY::type",                  "IM_TYPE",                             'V' ],
[ "INT::File Type",                  "MA_TYPE",                             'V' ],
[ "INT::Orientation",                "ORIENTATION_PLS",                     'V' ],
[ "INT::File Suffix",                "SUFFIX",                              'V' ],
[ "INT::Address",	                 "ADDRESS",                             'V' ],
[ "EXIF::GPS Longitude",             "LONGITUDE",                           'V' ],
[ "EXIF::GPS Latitude",              "LATITUDE",                            'V' ],
);

my $PropBindString;
my $PropColumns;

my @PropColNames;
my %PropTypes;

my %PropValues;

foreach my $ind (0..$#PropMap) {
	my ($name, $col_name, $type) = ($PropMap[$ind][0], $PropMap[$ind][1], $PropMap[$ind][2]);
	($PropColNames[$ind], $PropTypes{$name}) = ($name, $type);
	dbg(8,"Props init: $name -- $col_name -- $type");
	$PropColumns .= ",$col_name";
	$PropBindString .= ',?';
}

my %Palette;
my %PaletteIndex;
my @ColoredKeys = (); # without W,G,B

my $identify_props=""; foreach(@identify_props_thumb) { $identify_props .= "%[$_]::"}; chop $identify_props; chop $identify_props;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $ImportTag=sprintf("IMPORT %4d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon,$mday,$hour,$min,$sec);
dbg(7,"Import Tag = $ImportTag");

my %Threads;
my $Parent=$$;

setpriority 'PRIO_PROCESS', $$, 20;	# run all threads at lowest possible priority

if(!$opt_threads) {					# use one thread per CPU if no option given
    $opt_threads=`grep ^processor /proc/cpuinfo | wc -l`+0;
}

dbg(1,"Using $opt_threads threads");

foreach(1..$opt_threads) { # Spawn all child threads:
	my $pipe = IO::Pipe->new();
	if(my $pid=fork) {		# Parent
		$pipe->writer();
		binmode $pipe, ":utf8";
		$Threads{$pid}=$pipe;
	} else {				# Child
		$pipe->reader(); 
		binmode $pipe, ":utf8";
		close(STDIN);
		setup_thread();
		child_loop($pipe);
		cleanup_thread();
		# exit; # Some nasty END or destructor code from Image::ObjectDetect hangs here!
		POSIX::_exit(0);
	}
};

# Parent:
parent_loop(); 
foreach(values %Threads) { $_->close; }
foreach(1..$opt_threads) { wait; }; # If a child dies we return from wait and write to no PIPE!
exit(0);

sub parent_loop {
	my @pids = keys %Threads;
	my $i=0;
	my $fileno=1;
	$SIG{'INT'} = sub { kill('INT', keys %Threads); foreach(keys %Threads) {wait;} die("Caught SIGINT $!\n"); };
	foreach(($#ARGV>=0) ? (@ARGV) : <STDIN>) {
		dbg(7,"Queueing file no $fileno: $_");
		$Threads{$pids[$i++]}->print ($_);
		$i %= ($#pids+1); # round-robin threads
		$fileno++;
	}
}

sub child_loop {
	my($pipe)=@_;
	while(<$pipe>) {
		chomp;
		$SIG{'INT'} = sub { die; };
		import_single_file($_);
	}
	close($pipe);
}

sub signature_as_char_string2 {
	return(join('',map($_+2,unpack("c*", $_[0]))));
}

my $dbh;
my $sth_find_file_by_path;
my $sth_find_file_by_md5sum;
my $sth_new_file;
my $sth_new_path;

my $face_detector;

sub init_colors {	# initialize color palette
	foreach ($dbh->selectall_array("select color_id, color_name, color_hex from ma_colors order by color_id asc")) {
		my($c_id,$c_name,$c_hex) = @$_;
		my $color = Graphics::ColorObject->new_RGBhex($c_hex);
		$Palette{$PaletteIndex{"$c_name"} = $c_id} = $c_name;
		push(@ColoredKeys,$c_id) if( ($c_name ne "White") and ($c_name ne "Grey") and ($c_name ne "Black") );
		my($l,$a,$b) = ($Palette{"LAB:L:$c_id"}, $Palette{"LAB:A:$c_id"}, $Palette{"LAB:B:$c_id"}) = @{$color->as_Lab()};
        ($l,$a,$b) = split(',',sprintf(sprintf("%.2f,%.2f,%.2f",$l,$a,$b)));
		my($hh,$ss,$ll) = ($Palette{"HSL:H:$c_id"}, $Palette{"HSL:S:$c_id"}, $Palette{"HSL:L:$c_id"}) = @{$color->as_HSL()};
        dbg(7,"Palette color ".$c_name." is \tHSL($hh,$ss,$ll); \tLAB=($l,$a,$b)")
	}
}

sub setup_thread {
	$face_detector = Image::ObjectDetect->new($cascade);
	$dbh = DBI->connect("dbi:Oracle:","$opt_connect_string", undef, { PrintError => 1, RaiseError => 1, AutoCommit => 0 } );
	$sth_find_file_by_path = $dbh->prepare("select count(1) from MA_PATHS where path = ?");
	$sth_find_file_by_md5sum = $dbh->prepare("select file_id from MA_FILES where md5sum = ?");
	$sth_new_path = $dbh->prepare("insert into MA_PATHS (file_id,path) values (?,?)");
	# Problem: dates like '2006:02:14 15:41:13+02:00' not fit the 'YYYY:MM:DD HH24:MI:SS' mask
	$sth_new_file = $dbh->prepare("insert into MA_FILES (file_id,bytes,cdate,md5sum,thumb,lpuzzle,taken $PropColumns) values (?,?,sysdate,?,?,?,to_date(?,'YYYY:MM:DD HH24:MI:SS') $PropBindString)");
	init_colors();
}
  

sub cleanup_thread {
	#  undef $face_detector;
	$dbh->disconnect;
}

sub path_is_duplicate {
	$sth_find_file_by_path->execute(@_);
	my($rv) = $sth_find_file_by_path->fetchrow_array;
	$sth_find_file_by_path->finish;
	return($rv>0);
}

sub find_by_md5sum {
	$sth_find_file_by_md5sum->execute(@_);
	my($rv) = $sth_find_file_by_md5sum->fetchrow_array;
	$sth_find_file_by_md5sum->finish;
	return($rv);
}

sub is_url {
	my($path)=@_;
	my $url = url @_[0];
	return(1) if(($url->scheme eq "http") or ($url->scheme eq "https") or ($url->scheme eq "ftp"));
	return(0);
}

my $date_taken;
my %ImageProps;

sub import_single_file { # some threads die here when JPG is broken. And parent die then trying to write to a closed pipe ;)
   my($urlpath)=@_;
   my $dupe=path_is_duplicate($urlpath);
   if((!$opt_rewrite) && $dupe) {
   	   dbg(2,"Skip duplicate path: '$urlpath'");
   	   return;
   }
   my($path) = $urlpath;
   my $path_is_url = is_url($urlpath);
   if($path_is_url) { # get remote file into temporary local file
   	   $path="$opt_tmp/local-$$.image";
       my $rc=getstore($urlpath,$path);
       if(!is_success($rc)) {
       	   dbg(1,"$urlpath: HTTP ERROR=".status_message($rc)); 
       	   return;
       }
   }
   my @stat=stat($path);
   if(!@stat) {
   	   dbg(1,"stat($path) failed $!");
   	   return;
   }
   return if(-d $path); # directory
   return if(-b $path); # device

   undef %PropValues;
   
   my $bytes = $stat[7];	# file size in bytes
   my($filename, $directories, $suffix, $suffix_uc);
   if(!$path_is_url) {
   	   ($filename, $directories, $suffix) = fileparse($path, '\.[^\.]*');
   	   $suffix =~ s/^\.//;
   	   $suffix_uc = uc($suffix);
   }
   # my $file_type=`file -b --mime-type '$path'`;
   my $file_type=`file -b '$path'`;
   return if($file_type !~ /image/);
   $file_type =~ s/\n//g;
   dbg(1,"[thread=$$] \tProcessing file '$urlpath'...");
   my $md5sum=md5sum_string($path);
   dbg(6,"MD5SUM=$md5sum");
   my $file_id=find_by_md5sum($md5sum);
   my $is_binary_duplicate=0;
   if(length($file_id)) {
        dbg(6,"FILE '$urlpath' is a binary duplicate");
        $is_binary_duplicate=1;
   } else {
        $file_id=db_select_single("select MA_SEQ_FILES.NEXTVAL from DUAL");
   }
   dbg(6,"FILE_ID=$file_id for '$urlpath'");

   if(!$is_binary_duplicate) { # populate child first
          # fetch EXIF props:
          %ImageProps=undef; 	# to construct some INT:: props later from
          my $exifTool = new Image::ExifTool;
          $exifTool->Options(Duplicates => 0, CoordFormat => "%+.6f");
          my $exif=$exifTool->ImageInfo($path);
          my %exif = $exif;
          # return 0 if(defined($$exif{"Error"}));
    
          # add EXIF props:
          $date_taken="";
          foreach my $prop_name (sort keys %$exif) {
          	   my $long_prop_name = $exifTool->GetDescription($prop_name);
          	   add_prop("EXIF::$long_prop_name",$$exif{"$prop_name"});
          }
    
          # form some temp pathnames:
          my($thumb_path,$preview_path) = ("$opt_tmp/THUMB-$file_id.jpg", "$opt_tmp/PREVIEW-$file_id.jpg");
    
          # RAW or not?
          my $is_raw = ($file_type =~ / raw /i);   
    
          # Fetch street address from Google Maps API:
          $PropValues{"EXIF::GPS Longitude"} =~ s/^\+//; # google does not like PLUS signs
          $PropValues{"EXIF::GPS Latitude"}  =~ s/^\+//; # google does not like PLUS signs
          dbg(4,"GPS coords: ". $PropValues{"EXIF::GPS Longitude"} ."; ".$PropValues{"EXIF::GPS Latitude"});
          if((abs($PropValues{"EXIF::GPS Longitude"})>0) and (abs($PropValues{"EXIF::GPS Latitude"})>0)) {
          	   $PropValues{"INT::Address"} = get_street_address($PropValues{"EXIF::GPS Longitude"},$PropValues{"EXIF::GPS Latitude"});
          	   dbg(4,"Address is ".$PropValues{"INT::Address"});
          }
    
          # Fix Orientation:
          my $orientation = $PropValues{"EXIF::Orientation"};
          my $rotate;
          $rotate = "90" if($orientation =~ /90/);
          $rotate = "180" if($orientation =~ /180/);
          $rotate = "270" if($orientation =~ /270/);
          if( ($rotate eq "90") or ($rotate eq "270") ) { # swap width and height: 
          	   ($PropValues{"EXIF::Image Height"}, $PropValues{"EXIF::Image Width"}) = ($PropValues{"EXIF::Image Width"}, $PropValues{"EXIF::Image Height"});
          };
          $rotate = "-rotate $rotate" if(defined($rotate));
    
          # prepare thumbnail & preview images:
          my $quoted_path = $path;
          $quoted_path =~ s/'/'"'"'/g;
          if($is_raw) {
            # better not use --embedded-image here for it is of unknown size and orientation:
            my_system("ufraw-batch --silent --size=${opt_thumb_size}x${opt_thumb_size} --out-type=jpg --noexif --output=- --wb=camera '$quoted_path' > '$thumb_path'");
            my_system("ufraw-batch --silent --size=${opt_preview_size}x${opt_preview_size} --out-type=jpg --noexif --output=- --wb=camera '$quoted_path' > '$preview_path'");
          } else {
            # source images may be too big here:
            my_system("convert -format jpg $rotate -strip -thumbnail ${opt_thumb_size}x${opt_thumb_size} '$quoted_path' jpeg:- > '$thumb_path'");
            my_system("convert -format jpg $rotate -scale ${opt_preview_size}x${opt_preview_size} '$quoted_path' jpeg:- > '$preview_path'");
          };
    
          unlink($path) if($path_is_url); # remove local temporary copy
    
          my $thumb=slurp_file($thumb_path); unlink($thumb_path);
    
          # Fetch major colors. See http://www.imagemagick.org/Usage/compare/#metrics how
#   #      my $color_cmd = "convert '$preview_path' -scale ${opt_preview_size}x${opt_preview_size}\\! -colors $opt_colors +dither -compress none -depth 8 -format %c  -colorspace HSL histogram:info:- | sort -nr"; 
#   #      my $color_cmd = "convert '$preview_path' -scale ${opt_preview_size}x${opt_preview_size} -colors $opt_colors +dither -compress none -depth 8 -format %c  -colorspace HSL histogram:info:- | sort -nr"; 
#   #      my $color_cmd = "convert '$preview_path' -colors $opt_colors +dither -compress none -depth 8 -format %c  -colorspace HSL histogram:info:- | sort -nr"; 
          my $color_cmd = "convert '$preview_path' -colors $opt_colors -compress none -depth 8 -format %c  -colorspace HSL histogram:info:- | sort -nr"; 
          dbg(4,"Check major colors cmd: $color_cmd");
          my @colors = split("\n", my $color_out=`$color_cmd`);
          dbg(4,"Cmd output is:\n$color_out");
          
          # fetch avg saturation of the image:
          my $sat_cmd='identify -quiet -colorspace HSL -format "%[fx:mean.g]" ';
          my $saturation=`$sat_cmd '$preview_path'` + 0.0;
          dbg(8,"saturation=$saturation");
    
          my $total_pixels=0;	# total pixels in the preview of the image
          my %Pixels;			# number of pixels of a palette color
    
          foreach(my $c=0; $c<=$#colors; $c++) {
               my($pixels) = (split(':',$colors[$c]))[0]+0; 
               $total_pixels += $pixels;
               $colors[$c] =~ s/^.*hsl.*\(//; 
               $colors[$c] =~ s/\).*//;
               my($h,$s,$l)=split(',',$colors[$c]);
               dbg(6,"Color line [$c] for '$urlpath' is HSL($h,$s,$l)");
               ($h, $s, $l) = ($h*360/100, $s/100, $l/100);	# normalize
               my($color,$color_distance) = (lc($opt_color_match) eq "lab") ? NearestColorLAB($h,$s,$l,$saturation) : NearestColorHSL($h,$s,$l,$saturation);
               next if($color_distance > $opt_color_distance); # too far from palette
               $Pixels{$color} += $pixels;
          }
          
          my $nc=0;	# counter. only 2 colors matter;
          foreach my $cid (sort { $Pixels{$a} <=> $Pixels{$b} } keys %Pixels) {
          	   next if($Pixels{$cid} < $total_pixels*$opt_color_fraction);       # too few pixels of same color
          	   next if(++$nc > 2);
          	   add_prop("INT::Color".$nc, $cid);
          	   add_prop("INT::ColorDistance".$nc, (100 - ($Pixels{$cid}/$total_pixels)*100));
          }
    
          # fetch some other props:
          my %Identify; 
          my $ii=0;
          dbg(6,"CMD:: identify -quiet -format '$identify_props' '$preview_path'");
          foreach(split(/::/,`identify -quiet -format '$identify_props' '$preview_path'`)) { 
          	   my($P,$p);
          	   s/\n//g;
          	   $P = $Identify{$p=$identify_props_thumb[$ii++]} = $_; 
          	   dbg(8,"identify[$p]=$P");
          };
    
          # fill in LIBPUZZLE image fingerprint:
          my $lpuzzle;
          my $lpl;
          eval { $lpuzzle=libpuzzle_string($preview_path); };
          dbg(6,"LIBPUZZLE($urlpath): $lpuzzle=libpuzzle_string($preview_path)");
          if(($lpl=length($lpuzzle)) ne $opt_puzzle_len) { # something went wrong, may be broken JPG, etc.
          	   dbg(1,"Can't LIBPUZZLE '$preview_path'. Length returned=$lpl. Rollback");
          	   $dbh->rollback;
          	   return;
          }
    
          # replace database record if needed:
          if($dupe) { # Just renew record
              dbg(6,"Updating path '$urlpath'...");
              $dbh->do("delete from MA_FILES where path=?", undef, $urlpath);
          }
    
          # bind variables and INSERT into MA_FILES:
          eval {
          	   $sth_new_file->bind_param(1, $file_id) 		or die $sth_new_file->errstr;
          	   $sth_new_file->bind_param(2, $bytes) 		or die $sth_new_file->errstr;
          	   $sth_new_file->bind_param(3, $md5sum) 		or die $sth_new_file->errstr;
          	   $sth_new_file->bind_param(4, $thumb, { ora_type => ORA_BLOB }) or die $sth_new_file->errstr;
          	   $sth_new_file->bind_param(5, $lpuzzle) 		or die $sth_new_file->errstr;
          }; 
          my($err,$errstr) = ($sth_new_file->err, $sth_new_file->errstr);
    
          # add the rest of the props:
          add_prop('INT::Faces',get_faces($preview_path));		unlink($preview_path);
          add_prop('INT::Saturation',$saturation);
          add_prop('INT::File Type',$file_type);
          add_prop('INT::File Name',$filename);
          add_prop('INT::Directories',$directories);
          add_prop('INT::File Suffix',$suffix);
          add_prop('INT::Orientation', ('Landscape','Square','Portrait')[($PropValues{"EXIF::Image Height"} <=> $PropValues{"EXIF::Image Width"})+1]);
          # Squares may not be exact but approximate: (width ~ height). Visually they are also squares. We might take it into account somehow here
    
          # add even more props:
          foreach my $prop_name (sort keys %Identify) {
          	   my $long_prop_name = $exifTool->GetDescription($prop_name);
          	   add_prop("IDENTIFY::$prop_name",$Identify{"$prop_name"});
          }
    
          # some more fields to bind:
          eval { $sth_new_file->bind_param(6, $date_taken) or die $sth_new_file->errstr; };
          
          # all props ready at %PropValues now
          # bind the rest of the props and execute INSERT into MA_FILES:
          eval {
              foreach(0..$#PropMap) { 
		 $sth_new_file->bind_param(7+$_, $PropValues{$PropColNames[$_]}) or die $sth_new_file->errstr; 
              };
          };
          
          eval { $sth_new_file->execute; };
          my($err,$errstr) = ($sth_new_file->err, $sth_new_file->errstr);
          
          $urlpath =~ s/\//\/\//; # mark first file occurence by additionally / at the beginning of PATH to search for // then
   }
   
   eval { $sth_new_path->execute($file_id,$urlpath); or die $sth_new_path->errstr; };  
   my($err,$errstr) = ($sth_new_path->err, $sth_new_path->errstr);
   
   dbg(9,"Committing '$urlpath' record...");
   $dbh->commit;
}

my %PropIds;

sub add_prop {
   my($prop_name,$prop_value) = @_;
   # $prop_value may be a reference to scalar (thumbnail image) here
   dbg(8,"add-prop in: $prop_name, $prop_value");
   my $prop_id;
   
   # normalize some props:
   
   $date_taken = substr($prop_value,0,19) if(!$date_taken && ($prop_name eq "EXIF::Date/Time Original"));
   $prop_value =~ s/ C$// if($prop_name eq "EXIF::Camera Temperature");
   $prop_value =~ s/ [NSEW]$// if($prop_name =~ /^EXIF::GPS L.*itude$/);
   $prop_value /= (256**2) if($prop_name eq "IDENTIFY::mean"); # average brightness is here. normalize it to 1.0
   if($prop_name eq "EXIF::AF Points In Focus") { # just count point in focus
   	   my @points = split(/,/,$prop_value);
   	   $prop_value = $#points + 1;
   	   $prop_name = "INT::AF NO of Points In Focus"
   }
   if($prop_name eq "EXIF::Depth Of Field") { # "EXIF::Depth Of Field" = "3.92 m (2.65 - 6.57 m)" = "inf (1.59 m - inf)"
   	   $prop_value =~ s/.*\(//;
   	   $prop_value =~ s/\).*//;
   	   my($from,$to) = split(' - ',$prop_value);
   	   $from =~ s/ m//;
   	   $to =~ s/ m//;
   	   $to = "99999" if($to =~ /inf/); # Convert infinity to a number
   	   add_prop("INT::Depth Of Field From",$from);
   	   add_prop("INT::Depth Of Field To",$to);
   	   return;
   }
   return if (($prop_name =~ /^EXIF::/) && (!grep { $prop_name eq $_ } @valid_exif_props)); # Skip most EXIF props except listed
   dbg(8,"add-prop do out: $prop_name, $prop_value");

   $PropValues{$prop_name} = ($PropTypes{$prop_name} eq 'N') ? ($prop_value+0) : $prop_value; 
}

sub my_system {
   my($cmd)=@_;
   dbg(7,"HOST CMD: $cmd");
   return system($cmd);
}

sub db_select_single {
   my($sql)=@_;
   my $sth = $dbh->prepare($sql);
   $sth->execute;
   my($rv) = $sth->fetchrow_array;
   return $rv;
}

sub md5sum_string {
   open (my $MD5, '<', $_[0]) or die "Can't open '$_[0]': $!";
   binmode ($MD5);
   my $md5=Digest::MD5->new->addfile($MD5)->hexdigest;
   close($MD5);
   return $md5;
}

sub libpuzzle_string {
   my($file)=@_;
   my $pic = Image::Libpuzzle->new;
   $pic->set_max_width($opt_max_img_size); 
   $pic->set_max_height($opt_max_img_size);
   # lets change some LIBPUZZLE's defaults:
   $pic->set_lambdas($opt_lambdas);
   # $pic->set_autocrop(0);   
   $pic->set_p_ratio(2);	# 2 - default
   my $str;
   eval { $str = signature_as_char_string2($pic->fill_cvec_from_file($file)); } or warn $!;
   return $str;
}

sub cat { # we use slurp_file instead
	my($fname)=@_;
	unless(open FILE, $fname) { die "Unable to open '$fname': $!\n"; }
	binmode(FILE);
	local $/ = undef;
	my $contents = <FILE>;
	close FILE;
	return $contents;
}

sub slurp_file { use File::Find; return read_file($_[0], binmode => ':raw'); }

sub get_faces {	# Get number of faces in the image (by OpenCV lib):
	my($file)=@_;
	dbg(7,"Look for faces in '$file'");
	# return(`perl -e 'use Image::ObjectDetect; \$d=Image::ObjectDetect->new("/usr/share/opencv/haarcascades/haarcascade_frontalface_alt2.xml"); \@f=\$d->detect("$file"); print(\$#f+1);'`+0);
	my @faces = $face_detector->detect($file);
	return($#faces+1);
}

sub dbg {
	my($level,@rest)=@_;
	return if($level >= $opt_debug);
	print STDOUT ("DBG($level): ",@rest,"\n");
}

sub NearestColorHSL { # get nearest palette color
	my($H,$S,$L,$saturation)=@_;
	my($c_id,$D) = (undef,999);
	my @Keys;
    warn("HSL=($H,$S,$L) is out of colorspace range!") if(($H<0) or ($H>360) or ($S<0) or ($S>1) or ($L<0) or ($L>1));
    dbg(7,"HSL = $H,$S,$L");
	my $c = Graphics::ColorObject->new_HSL([$H, $S, $L]);
	@Keys = (($saturation<0.1) and ($S<0.3)) ? ($PaletteIndex{"Grey"}, $PaletteIndex{"White"}, $PaletteIndex{"Black"})  : @ColoredKeys;
	foreach my $c_id1 (sort @Keys) {
        dbg(8," Comparing HSL=($H,$S,$L) to palette color HSL=(",$Palette{"HSL:H:$c_id1"}.",".$Palette{"HSL:S:$c_id1"}.",".$Palette{"HSL:L:$c_id1"}, "); (dirty=$opt_color_dirty)");
        next if((abs($S-$Palette{"HSL:S:$c_id1"})>$opt_color_dirty) or (abs($L-$Palette{"HSL:L:$c_id1"})>$opt_color_dirty/2));  # Check for pure colors only. [H,S,L] of pallette color is usualy like [H, 0.5, 1.0] btw
        my $distance = abs($H - $Palette{"HSL:H:$c_id1"});
        $distance = (360-$distance) if($distance > 180);
        $distance = sprintf("%.2f", $distance); 
        dbg(7,"-> Color ".$Palette{$c_id1}." is $distance far from HSL=$H,$S,$L");
		if($distance<$D) {
			$D=$distance;
			$c_id=$c_id1;
		}
	}
    dbg(5,"-> Best color ".$Palette{$c_id}." is $D far from HSL=$H,$S,$L");
	return($c_id,$D);
}


sub NearestColorLAB { # get nearest palette color
	my($H,$S,$L,$saturation)=@_;
	my($c_id,$D) = (undef,999);
	my @Keys;
    warn("HSL=($H,$S,$L) is out of colorspace range!") if(($H<0) or ($H>360) or ($S<0) or ($S>1) or ($L<0) or ($L>1));
    dbg(7,"HSL = $H,$S,$L");
	my $c = Graphics::ColorObject->new_HSL([$H, $S, $L]);
	my($lab_L,$lab_A,$lab_B) = @{ $c->as_Lab() };
    ($lab_L,$lab_A,$lab_B) = split(',',sprintf(sprintf("%.2f,%.2f,%.2f",$lab_L,$lab_A,$lab_B)));
	@Keys = (($saturation<0.1) and ($S<0.3)) ? ($PaletteIndex{"Grey"}, $PaletteIndex{"White"}, $PaletteIndex{"Black"})  : @ColoredKeys;
	foreach my $c_id1 (sort @Keys) {
        next if((abs($S-$Palette{"HSL:S:$c_id1"})>$opt_color_dirty) or (abs($L-$Palette{"HSL:L:$c_id1"})>$opt_color_dirty/2));  # Check for pure colors only. [H,S,L] of pallette color is usualy like [H, 1.0, 0.5] btw
        my $distance=sprintf(sprintf("%.2f", delta_e_2000(pdl([$lab_L,$lab_A,$lab_B]),pdl([$Palette{"LAB:L:$c_id1"}, $Palette{"LAB:A:$c_id1"}, $Palette{"LAB:B:$c_id1"}]))));
        dbg(7,"-> Color ".$Palette{$c_id1}." is $distance far from LAB=$lab_L,$lab_A,$lab_B");
		if($distance<$D) {
			$D=$distance;
			$c_id=$c_id1;
		}
	}
    dbg(5,"=> Best color ".$Palette{$c_id}." is $D far from LAB($lab_L,$lab_A,$lab_B)");
	return($c_id,$D);
}

sub geo_distance {	# returns distance on Earth in kilometers
    my($lon1,$lat1,$lon2,$lat2) = @_;
    my $geo = Geo::Distance->new;
    return $geo->distance('kilometer',$lon1,$lat1,$lon2,$lat2);
}

my %Addresses;	# street address cache (might memcached be here?)

sub get_street_address {	# ask Google
    my($lon,$lat) = @_;
    my $loc="$lat,$lon";
    # fetch cached addresses first, then ask google
    # we'd better use memcached here
    dbg(7,"1 Location = $loc");
    my($nearest_dist, $nearest_place);
    foreach my $place (keys %Addresses) { my $d;
    	($nearest_dist,$nearest_place)=($d, $place) if(!defined($nearest_dist) or ($d=geo_distance(split(',',$place),$lon,$lat)<$nearest_dist));
    }
    dbg(7,"2 Location = $loc");
    return $Addresses{$nearest_place} if((defined($nearest_dist)) and ($nearest_dist<1)); # consider 1km distance to be the same place
    dbg(7,"3 Location = $loc");
    sleep(3); # not to bump Google's free 50 requests per second limit
    dbg(7,"4 Location = $loc");
    my $geocoder = Geo::Coder::Googlev3->new;
    dbg(7,"5 Location = $loc");
    my $location = $geocoder->geocode(location => $loc);
    dbg(7,"6 Location = $loc");
    return($Addresses{$loc} = $location->{'formatted_address'});
}

__DATA__

