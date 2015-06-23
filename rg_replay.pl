#!/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
# Theme Stuff based upon ReplaySchedule.pl by Kevin J. Moye
#
# REPLAYTV/GUIDESNAPSHOT FUNCTIONS
#
#------------------------------------------------------------------------------------
# This file is part of Personal ReplayGuide (C) 2003 by Lee Thompson
#
# Personal ReplayGuide is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Personal ReplayGuide is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Personal ReplayGuide; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#-----------------------------------------------------------------------------------

require HTTP::Request;
require HTTP::Headers;
require LWP::UserAgent;
use Time::Local;
use POSIX qw( strftime getcwd );

my $_version = "Personal ReplayGuide|ReplayTV GuideSnapshot Library|1|0|10|Lee Thompson,Kanji T. Bates,Kevin J. Moye";

#------------------------------------------------------------------------------------
# Determine Current Directroy 
#------------------------------------------------------------------------------------

$current_dir = getcwd;
$current_dir .= "/";

#------------------------------------------------------------------------------------
# Get script pathname, unfortunately on Apache on Win32 $0 is not reliable since
# for some reason it gets changed to an 8.3 pathname.
#
# IIS and Apache both provide long filename pathnames in environment variables so
# if it's an 8.3 we look there.   If we don't find it, we just tough it out.
#------------------------------------------------------------------------------------

$script_pathname = $0;

if ($0 =~ /\~/) {
	if (length($ENV{SCRIPT_FILENAME}) > 0 ) {
		$script_pathname = $ENV{SCRIPT_FILENAME};
	}
	
	if (length($ENV{PATH_TRANSLATED}) > 0 ) {
		$script_pathname = $ENV{PATH_TRANSLATED};
	}
}

#------------------------------------------------------------------------------------
# Get the path that the script is in
#------------------------------------------------------------------------------------

(my $path,my $basename) = $script_pathname =~ m|^(.*[/\\])([^/\\]+?)$|;

#------------------------------------------------------------------------------------
# PRG_HOME is an override environment variable
#------------------------------------------------------------------------------------

if (length($ENV{PRG_HOME}) > 0) {
	$path = $ENV{PRG_HOME};
}

#------------------------------------------------------------------------------------
# Normalize the path
#------------------------------------------------------------------------------------

$path =~ s/\\/\//g;

#------------------------------------------------------------------------------------
# If the current working directory is not where we need to be, change paths.
#------------------------------------------------------------------------------------

$changed_path = -1;

if (($current_dir ne $path) && ($path ne "")) {
	if (chdir $path) {
		$changed_path = 1;
	}else{
		$changed_path = 0;
	}
}

#------------------------------------------------------------------------------------
# Load Libraries
#------------------------------------------------------------------------------------

require 'rg_common.pl';

#------------------------------------------------------------------------------------
# Set up module identification
#------------------------------------------------------------------------------------

my $module_name = "";
(my $debug_package, my $debug_filename, my $debug_line, my $debug_subroutine, my $debug_hasargs, my $debug_wantarray, my $debug_evaltext, my $debug_isrequire) = caller(0);
if (length($debug_evaltext) > 0) {
	$module_name = $debug_evaltext;
}else{
	if ($path eq "") {
		$basename = $script_pathname;
	}
	$module_name = $basename;
}
$prg_module{$module_name} = $_version;

@qualitylabel = ( 
	"High", 
	"Medium", 
	"Standard" 
);

#------------------------------------------------------------------------------------
# Set up arrays
#------------------------------------------------------------------------------------

@channeltypelabel = (
	"Recurring",
	"Theme",
	"Single",
	"Zone"
);

#------------------------------------------------
sub getReplayGuide {
	#
	# Get ReplayGuide replayid
	#
	#---------------------------------------------------------------------------
	my $retcode = 0;
	my $replayid = shift;
	my $replayaddr = $rtvaddress{$replayid};
	my $replayport = $rtvport{$replayid};
	my $snapshottime = time;

	if ($debug) {
		print "getReplayGuide::Downloading Guide Snapshot for $replayid: $rtvaddress{$replayid}\n";
	}

	$guideptr = 0;

	if (length($replayaddr) < 1) {
		return 0;
	}

	#--------------------------------------------------------------
	# Ready URL
	#--------------------------------------------------------------

	if ($replayport != 80) {
		$replaycmd = "http://$replayaddr:$replayport/http_replay_guide-get_snapshot?guide_file_name=0";
	}else{
		$replaycmd = "http://$replayaddr/http_replay_guide-get_snapshot?guide_file_name=0";
	}

	#--------------------------------------------------------------
	# Download Guide Snapshot
	#--------------------------------------------------------------

	if ($debug) {
		print "getReplayGuide::HTTP::Request->new(GET => $replaycmd)\n";
	}

	$ua = LWP::UserAgent->new;
	$request = HTTP::Request->new(GET => $replaycmd);
	$response = $ua->request($request);

	if ($response->is_success) {
		$guidesnapshot = $response->content;
		if ($debug) {
			print "getReplayGuide::Download Successful\n";
		}

	}else{
		if ($debug) {
			print "getReplayGuide::Download Failed\n";
		}
		return 0;
	}
		
	#--------------------------------------------------------------
	# Strip off extra bits
	#--------------------------------------------------------------

	if ($debug) {
		print "getReplayGuide::Trimming\n";
	}

	($guidetag,$junk,$snapshotbody,$junk2) = split(/#####/, $guidesnapshot, 9);

	#--------------------------------------------------------------
	# $guidesnapshot contains the binary image of the snapshot
	#--------------------------------------------------------------

	if ($debug) {
		print "getReplayGuide::Completed\n";
	}

	return 1;
}



#------------------------------------------------
sub normalizertvname {
	# Normalize a program/show title
	#
	# returns altered string
	#
	#---------------------------------------------------------------------------

	my @string = split(//,shift); 

	my $newstring = "";
	my ($i, $j, $add, $c); 
	my @s = (); 
	$j = 0;
	for( $i=0; $i<=$#string; $i++ ) { 
		$add = 1; 
		$c = $string[$i]; 
		## Non-alphanumeric and non-space character are skipped 
		if( $c !~ /([a-z]|[0-9])/i && ! ($c eq " ") ) { 
			if ( $c eq "-" || "$c" eq "/" ) { 
				$c = ' '; 
			} else { 
				$add = 0; 
			} 
		} 

		## Avoid 2 spaces in a row 
		if( $j > 0 && $c eq " " && $s[$j-1] eq " " ) { 
			$add = 0; 
		} 

		if( $add ) { 
			$s[$j++] = lc($c); 
		} 
	} 

	return(join("",@s)); 
}

#------------------------------------------------
sub collectRTVShows {
	#
	# Collect RTV shows 
	# Parameter: Replay IDs (comma delimited)
	#
	# Builds $events array
	#
	# replayid;eventtime (GMT);guaranteed;channeltype;daysofweek;channelflags;
	# beforepadding;afterpadding;showlabel;channelname
	#
	#---------------------------------------------------------------------------

	my $replayidlist = shift;

	if ($debug) {
		print "collectRTVShows::gather shows from replay units #$replayidlist\n";
	}

	my $ctr = 1;
	my $rtvshowcount = 0;

	for ( split /,/, $replayidlist ) {
		/,/;
		my $replayid = $_;
		my $replayaddr = $rtvaddress{$replayid};
		$category = "";
		my $guideptr = 0;
		my $guideheader = "";
		my $groupdata = "";
		my $snapshotbody = "";
		my $rtvchannel = "";
		my $rtvshow = "";

		if ($debug) {
			print "collectRTVShows::Processing Data for $replayid: $rtvaddress{$replayid}\n";
		}


		if ($debug) {
			print "collectRTVShows::Attempting to Download Snapshot from $replayid: $rtvaddress{$replayid}\n";
		}

		if (length($guidesnapshot{$replayid}) < 1) {
			if (getReplayGuide($replayid)) {
				if ($debug) {
					print "collectRTVShows::Snapshot download from $replayid: $rtvaddress{$replayid} OK\n";
				}
				$guidesnapshot{$replayid} = $snapshotbody;
			}else{
				if ($debug) {
					print "collectRTVShows::Snapshot download from $replayid: $rtvaddress{$replayid} FAILED\n";
				}
				next;
			}
		}else{
			if ($debug) {
				print "collectRTVShows::Using snapshot from memory\n";
			}
			$snapshotbody = $guidesnapshot{$replayid};
		}

		if ($debug) {
			print "collectRTVShows::Parsing Snapshot Header\n";
		}

		if (&ParseRTVHeader) {

			$rtv_version{$replayid} = $guideheader{snapshotversion};

			if ($debug) {
				print "collectRTVShows::Gathering Show Data\n";
			}

			$ctr = 1;
			my $status = 0;

			do {
				$status = getRTVShow($ctr);
				if ($status) {
					if ($debug) {
						print "collectRTVShows::Processing Show #$ctr $replayid: $rtvaddress{$replayid} ($rtvshowcount total)\n";
					}
					$ctr++;
					$rtvshowcount++;
					$rtvshows[$rtvshowcount] = "$replayid|$rtvshow{created}|$rtvshow{recorded}|$rtvshow{inputsource}|$rtvshow{quality}|$rtvshow{guaranteed}|$rtvshow{tmsid}|$rtvshow{channel}|$rtvshow{channelname}|$rtvshow{channellabel}|$rtvshow{tuning}|$rtvshow{eventtime}|$rtvshow{programtmsid}|$rtvshow{minutes}|$rtvshow{desc_block}|$rtvshow{beforepadding}|$rtvshow{afterpadding}";
				}
			} while $status;

			$guideheader{showcount} = $ctr;		# Fake Guide Entry :)

		}
	}

#	@rtvshows = sort {$a <=> $b} @rtvshows;

	if ($debug) {
		print "collectRTVShows::Completed ($rtvshowcount)\n";
	}

	return $rtvshowcount;
}


#------------------------------------------------
sub collectRTVChannels {
	#
	# Collect RTV Events 
	# Parameter: Replay IDs (comma delimited)
	#	     Format (if 1 uses the old rg_guide format)
	#
	# Builds $events array
	#
	# replayid;eventtime (GMT);guaranteed;channeltype;daysofweek;channelflags;
	# beforepadding;afterpadding;showlabel;channelname
	#
	#---------------------------------------------------------------------------

	my $replayidlist = shift;
	my $format = int shift;

	if ($debug) {
		print "collectRTVChannels::gather channels from replay units #$replayidlist\n";
	}

	my $ctr = 1;
	my $events = 0;

	for ( split /,/, $replayidlist ) {
		/,/;
		my $replayid = $_;
		my $replayaddr = $rtvaddress{$replayid};
		$category = "";
		my $guideptr = 0;
		my $guideheader = "";
		my $groupdata = "";
		my $snapshotbody = "";
		my $rtvchannel = "";

		if ($debug) {
			print "collectRTVChannels::Processing Data for $replayid: $rtvaddress{$replayid}\n";
		}


		if (length($guidesnapshot{$replayid}) < 1) {
			if ($format) {
				if (0 != getCachedScheduleTable($replayid)) {
					if ($debug) {
						print "collectRTVChannels::Using snapshot from disk.\n";
					}
					$guidesnapshot{$replayid} = $snapshotbody;
				}
			}else{
				if ($debug) {
					print "collectRTVChannels::Attempting to Download Snapshot from $replayid: $rtvaddress{$replayid}\n";
				}
				if (getReplayGuide($replayid)) {
					if ($debug) {
						print "collectRTVChannels::Snapshot download from $replayid: $rtvaddress{$replayid} OK\n";
					}
					$guidesnapshot{$replayid} = $snapshotbody;
				}else{
					if ($debug) {
						print "collectRTVChannels::Snapshot download from $replayid: $rtvaddress{$replayid} FAILED\n";
					}
					next;
				}

			}

		}else{
			if ($debug) {
				print "collectRTVChannels::Using snapshot from memory\n";
			}
			$snapshotbody = $guidesnapshot{$replayid};
		}


		if ($debug) {
			print "collectRTVChannels::Parsing Snapshot Header\n";
		}


		if (&ParseRTVHeader) {
			$rtv_version{$replayid} = $guideheader{snapshotversion};
			$rtv_categories{$replayid} = "$groupdata{categorycount}|$category";

			if ($debug) {
				print "collectRTVChannels::Loading Categories\n";
			}

			$categories{$replayid} = $category;

			if ($debug) {
				print "collectRTVChannels::Gathering Channel Data ($guideheader{channelcount})\n";
			}

			
			$ctr = 1;

			do {
				if (getRTVChannel($ctr)) {
					if ($debug) {
						print "collectRTVChannels::Processing Channel #$ctr $replayid: $rtvaddress{$replayid} ($events total)\n";
					}
					$ctr++;
					if ($rtvchannel{ivsstatus} < 1) {
						if ($rtvchannel{channeltype} > 0) {
							$events++;
							if ($format) {
								$rtvevent[$events] = "$replayid;$rtvchannel{eventtime};$rtvchannel{guaranteed};$rtvchannel{channeltype};$rtvchannel{daysofweek};$rtvchannel{channelflags};$rtvchannel{beforepadding};$rtvchannel{afterpadding};$rtvchannel{showlabel};$rtvchannel{channelname};$rtvchannel{themeflags};$rtvchannel{searchstring};$rtvchannel{thememinutes};$rtvchannel{created}";
							}else{
								$rtvevent[$events] = "$replayid|$rtvchannel{created}|$rtvchannel{eventtime}|$rtvchannel{guaranteed}|$rtvchannel{channeltype}|$rtvchannel{daysofweek}|$rtvchannel{channelflags}|$rtvchannel{beforepadding}|$rtvchannel{afterpadding}|$rtvchannel{showlabel}|$rtvchannel{channelname}|$rtvchannel{themeflags}|$rtvchannel{searchstring}|$rtvchannel{thememinutes}|$rtvchannel{category}|$rtvchannel{keep}|$rtvchannel{_norepeats}|$rtvchannel{minutes}";
							}
							
							

						}
					}
				}
			} while $ctr <= $guideheader{channelcount};
		}
	}


	@rtvevent = sort {$a <=> $b} @rtvevent;

	if ($debug) {
		print "collectRTVChannels::Completed ($events)\n";
	}

	return $events;
}


#----------------------------------------------------------------------------------------
sub ParseRTVHeader {
	# Parse GuideSnapshot Header and Load Categories into a String (comma delim)
	#
	#--------------------------------------------------------------------------------

	$guideptr = 0;

	$guideheader{osversion} = &GetNextWORD;
	$guideheader{snapshotversion} = &GetNextWORD;

	if (($guideheader{snapshotversion} == 2) && ($guideheader{osversion} == 0)) {
		&ParseRTV50;
		return 1;
	}

	if (($guideheader{snapshotversion} == 1) && ($guideheader{osversion} == 5))  {
		&ParseRTV45;
		return 1;
	}

	if (($guideheader{snapshotversion} == 1) && ($guideheader{osversion} == 3))  {
		&ParseRTV43;
		return 1;
	}

	return 0;
}

#----------------------------------------------------------------------------------------
sub ParseRTV50 {
	# Parse 5.0 Header
	#
	#--------------------------------------------------------------------------------
	
	$guideheader{structuresize} = &GetNextDWORD;
	$guideheader{unknown1} = &GetNextDWORD;
	$guideheader{unknown2} = &GetNextDWORD;
	$guideheader{channelcount} = &GetNextDWORD;
	$guideheader{channelcountcheck} = &GetNextDWORD;
	$guideheader{unknown3} = &GetNextDWORD;
	$guideheader{groupdataoffset} = &GetNextDWORD;
	$guideheader{channeloffset} = &GetNextDWORD;
	$guideheader{showoffset} = &GetNextDWORD;
	$guideheader{snapshotsize} = &GetNextDWORD;
	$guideheader{freebytes} = &GetRaw(8);
	$guideheader{flags} = &GetNextDWORD;
	$guideheader{unknown6} = &GetNextDWORD;
	$guideheader{unknown7} = &GetNextDWORD;

	$groupdata{structuresize} = &GetNextDWORD;
	$groupdata{categorycount} = &GetNextDWORD;

	my $ctr = 0;

	do {
		$categories[$ctr] = &GetNextDWORD;
		$ctr++;
	} while ($ctr < 32);


	$ctr = 0;

	do {
		$categoryoffset[$ctr] = &GetNextDWORD;
		$ctr++;
	} while ($ctr < 32);
	

	$groupdata{catbuffer} = &GetRaw(512);


	# Load Categories

	$category = "";
	$ctr = 0;

	do {
		if ($ctr) {
			$category .= ";";
		}
		$category .= "$categories[$ctr],";
		$category .= unpack("Z16",substr($groupdata{catbuffer},$categoryoffset[$ctr]));
		$ctr++;
	} while ($ctr < $groupdata{categorycount});

	return 1;
}

#----------------------------------------------------------------------------------------
sub ParseRTV45 {
	# Parse 4.5 Header
	#
	#--------------------------------------------------------------------------------
	
	$guideheader{structuresize} = &GetNextDWORD;
	$guideheader{channelcount} = &GetNextDWORD;
	$guideheader{channelcountcheck} = &GetNextDWORD;
	$guideheader{groupdataoffset} = &GetNextDWORD;
	$guideheader{channeloffset} = &GetNextDWORD;
	$guideheader{showoffset} = &GetNextDWORD;
	$guideheader{flags} = &GetNextDWORD;

	$groupdata{structuresize} = &GetNextDWORD;
	$groupdata{categorycount} = &GetNextDWORD;

	my $ctr = 0;

	do {
		$categories[$ctr] = &GetNextDWORD;
		$ctr++;
	} while ($ctr < 32);


	$ctr = 0;

	do {
		$categoryoffset[$ctr] = &GetNextDWORD;
		$ctr++;
	} while ($ctr < 32);
	

	$groupdata{catbuffer} = &GetRaw(512);


	# Load Categories

	$ctr = 0;

	do {
		if ($ctr) {
			$category .= ";";
		}
		$category .= "$categories[$ctr],";
		$category .= unpack("Z16",substr($groupdata{catbuffer},$categoryoffset[$ctr]));
		$ctr++;
	} while ($ctr < $groupdata{categorycount});

	return 1;
}

#----------------------------------------------------------------------------------------
sub ParseRTV43 {
	# Parse 4.3 Header
	#
	#--------------------------------------------------------------------------------

	$guideheader{structuresize} = &GetNextDWORD;
	$guideheader{channelcount} = &GetNextDWORD;
	$guideheader{channelcountcheck} = &GetNextDWORD;
	$guideheader{groupdataoffset} = &GetNextDWORD;
	$guideheader{channeloffset} = &GetNextDWORD;
	$guideheader{showoffset} = &GetNextDWORD;
	$guideheader{flags} = &GetNextDWORD;

	$groupdata{structuresize} = &GetNextDWORD;
	$groupdata{categorycount} = &GetNextDWORD;

	my $ctr = 0;

	do {
		$categories[$ctr] = &GetNextDWORD;
		$ctr++;
	} while ($ctr < 32);


	$ctr = 0;

	do {
		$categoryoffset[$ctr] = &GetNextDWORD;
		$ctr++;
	} while ($ctr < 32);
	

	$groupdata{catbuffer} = &GetRaw(512);


	# Load Categories

	$ctr = 0;

	do {
		if ($ctr) {
			$category .= ";";
		}
		$category .= "$categories[$ctr],";
		$category .= unpack("Z16",substr($groupdata{catbuffer},$categoryoffset[$ctr]));
		$ctr++;
	} while ($ctr < $groupdata{categorycount});

	return 1;
}

#----------------------------------------------------------------------------------------
sub getRTVChannel {
	# Get RTV ReplayChannel #
	#
	# Dispatcher
	#
	#--------------------------------------------------------------------------------

	my $rtvchannel = int shift;

	if ($rtvchannel < 1) {
		return 0;
	}

	if (($guideheader{snapshotversion} == 2) && ($guideheader{osversion} == 0))  {
		&getRTVChannel50($rtvchannel);
		return 1;
	}

	if (($guideheader{snapshotversion} == 1) && ($guideheader{osversion} == 5))  {
		&getRTVChannel45($rtvchannel);
		return 1;
	}

	if (($guideheader{snapshotversion} == 1) && ($guideheader{osversion} == 3))  {
		&getRTVChannel43($rtvchannel);
		return 1;
	}

	return 0;
}


#----------------------------------------------------------------------------------------
sub getRTVChannel50 {
	# Get RTV ReplayChannel #
	#
	# For Channel Size: 712 (5.0)
	#
	#--------------------------------------------------------------------------------

	my $rtvchannel = int shift;

	#--------------------------------------------------------------------------------
	# Set Base
	#--------------------------------------------------------------------------------

	$guideptr = $guideheader{channeloffset} - 712;

	$guideptr = $guideptr + ($rtvchannel * 712);

	$rtvchannel{created} = &GetNextDWORD;
	$rtvchannel{recorded} = &GetNextDWORD;
	$rtvchannel{inputsource} = &GetNextDWORD;
	$rtvchannel{quality} = &GetNextDWORD;
	$rtvchannel{guaranteed} = &GetNextDWORD;
	$rtvchannel{playbackflags} = &GetNextDWORD;
	$rtvchannel{channelstructsize} = &GetNextDWORD;
	$rtvchannel{usetuner} = &GetNextDWORD;
	$rtvchannel{isvalid} = &GetNextDWORD;
	$rtvchannel{tmsid} = &GetNextDWORD;
	$rtvchannel{channel} = &GetNextWORD;
	$rtvchannel{device} = &GetNextBYTE;
	$rtvchannel{tier} = &GetNextBYTE;
	$rtvchannel{channelname} = &GetSZ(16);
	$rtvchannel{channellabel} = &GetSZ(32);
	$rtvchannel{headend} = &GetSZ(8);
	$rtvchannel{channelindex} = &GetNextDWORD;
	$rtvchannel{programstructsize} = &GetNextDWORD;
	$rtvchannel{autorecord} = &GetNextDWORD;
	$rtvchannel{isvalid} = &GetNextDWORD;
	$rtvchannel{tuning} = &GetNextDWORD;
	$rtvchannel{programflags} = &GetNextDWORD;
	$rtvchannel{eventtime} = &GetNextDWORD;
	$rtvchannel{programtmsid} = &GetNextDWORD;
	$rtvchannel{minutes} = &GetNextWORD;
	$rtvchannel{genre1} = &GetNextBYTE;
	$rtvchannel{genre2} = &GetNextBYTE;
	$rtvchannel{genre3} = &GetNextBYTE;
	$rtvchannel{genre4} = &GetNextBYTE;
	$rtvchannel{reclen} = &GetNextWORD;
	$rtvchannel{titlelen} = &GetNextBYTE;
	$rtvchannel{episodelen} = &GetNextBYTE;
	$rtvchannel{descriptionlen} = &GetNextBYTE;
	$rtvchannel{actorlen} = &GetNextBYTE;
	$rtvchannel{guestlen} = &GetNextBYTE;
	$rtvchannel{suzukilen} = &GetNextBYTE;
	$rtvchannel{producerlen} = &GetNextBYTE;
	$rtvchannel{directorlen} = &GetNextBYTE;
	$rtvchannel{description} = &GetRaw(228);
	$rtvchannel{ivsstatus} = &GetNextDWORD;
	$rtvchannel{guideid} = &GetNextDWORD;	
	$rtvchannel{downloadid} = &GetNextDWORD;	
	$rtvchannel{timessent} = &GetNextDWORD;
	$rtvchannel{seconds} = &GetNextDWORD;
	$rtvchannel{gopcount} = &GetNextDWORD;
	$rtvchannel{gophighest} = &GetNextDWORD;
	$rtvchannel{goplast} = &GetNextDWORD;
	$rtvchannel{checkpointed} = &GetNextDWORD;
	$rtvchannel{intact} = &GetNextDWORD;
	$rtvchannel{upgradeflag} = &GetNextDWORD;
	$rtvchannel{instance} = &GetNextDWORD;
	$rtvchannel{unused} = &GetNextWORD;
	$rtvchannel{beforepadding} = &GetNextBYTE;
	$rtvchannel{afterpadding} = &GetNextBYTE;
	$rtvchannel{indexsize} = &GetRaw(8);
	$rtvchannel{mpegsize} = &GetRaw(8);
	$rtvchannel{reserved} = &GetRaw(68);
	$rtvchannel{themeflags} = &GetNextDWORD;
	$rtvchannel{suzukiid} = &GetNextDWORD;
	$rtvchannel{thememinutes} = &GetNextDWORD;
	$rtvchannel{searchstring} = &GetSZ(48);
	$rtvchannel{created} = &GetNextDWORD;
	$rtvchannel{category} = &GetNextDWORD; # 2^category number
	$rtvchannel{channeltype} = &GetNextDWORD;
	$rtvchannel{quality} = &GetNextDWORD;
	$rtvchannel{stored} = &GetNextDWORD;
	$rtvchannel{keep} = &GetNextDWORD;
	$rtvchannel{daysofweek} = &GetNextBYTE;
	$rtvchannel{afterpadding} = &GetNextBYTE;
	$rtvchannel{beforepadding} = &GetNextBYTE;
	$rtvchannel{channelflags} = &GetNextBYTE;
	$rtvchannel{timereserved} = &GetRaw(8);
	$rtvchannel{showlabel} = &GetSZ(48);
	$rtvchannel{unknown1} = &GetNextDWORD;
	$rtvchannel{unknown2} = &GetNextDWORD;
	$rtvchannel{unknown3} = &GetNextDWORD;
	$rtvchannel{unknown4} = &GetNextDWORD;
	$rtvchannel{unknown5} = &GetNextDWORD;
	$rtvchannel{unknown6} = &GetNextDWORD;
	$rtvchannel{unknown7} = &GetNextDWORD;
	$rtvchannel{unknown8} = &GetNextDWORD;
	$rtvchannel{allocatedspace} = &GetRaw(8);
	$rtvchannel{unknown9} = &GetNextDWORD;
	$rtvchannel{unknown10} = &GetNextDWORD;
	$rtvchannel{unknown11} = &GetNextDWORD;
	$rtvchannel{unknown12} = &GetNextDWORD;

	if ($rtvchannel{channelflags} & 32) {
		$rtvchannel{_norepeats} = 1;
	}else{
		$rtvchannel{_norepeats} = 0;
	}

	return 1;
	
}


#----------------------------------------------------------------------------------------
sub getRTVChannel45($) {
	# UNTESTED
	#
	# Get RTV ReplayChannel #
	#
	# For Channel Size: 712
	#
	#--------------------------------------------------------------------------------

	my $rtvchannel = int shift;

	#--------------------------------------------------------------------------------
	# Set Base
	#--------------------------------------------------------------------------------

	$guideptr = $guideheader{channeloffset} - 712;

	$guideptr = $guideptr + ($rtvchannel * 712);

	$rtvchannel{created} = &GetNextDWORD;
	$rtvchannel{recorded} = &GetNextDWORD;
	$rtvchannel{inputsource} = &GetNextDWORD;
	$rtvchannel{quality} = &GetNextDWORD;
	$rtvchannel{guaranteed} = &GetNextDWORD;
	$rtvchannel{playbackflags} = &GetNextDWORD;
	$rtvchannel{channelstructsize} = &GetNextDWORD;
	$rtvchannel{usetuner} = &GetNextDWORD;
	$rtvchannel{isvalid} = &GetNextDWORD;
	$rtvchannel{tmsid} = &GetNextDWORD;
	$rtvchannel{channel} = &GetNextWORD;
	$rtvchannel{device} = &GetNextBYTE;
	$rtvchannel{tier} = &GetNextBYTE;
	$rtvchannel{channelname} = &GetSZ(16);
	$rtvchannel{channellabel} = &GetSZ(32);
	$rtvchannel{headend} = &GetSZ(8);
	$rtvchannel{channelindex} = &GetNextDWORD;
	$rtvchannel{programstructsize} = &GetNextDWORD;
	$rtvchannel{autorecord} = &GetNextDWORD;
	$rtvchannel{isvalid} = &GetNextDWORD;
	$rtvchannel{tuning} = &GetNextDWORD;
	$rtvchannel{programflags} = &GetNextDWORD;
	$rtvchannel{eventtime} = &GetNextDWORD;
	$rtvchannel{programtmsid} = &GetNextDWORD;
	$rtvchannel{minutes} = &GetNextWORD;
	$rtvchannel{genre1} = &GetNextBYTE;
	$rtvchannel{genre2} = &GetNextBYTE;
	$rtvchannel{genre3} = &GetNextBYTE;
	$rtvchannel{genre4} = &GetNextBYTE;
	$rtvchannel{reclen} = &GetNextWORD;
	$rtvchannel{titlelen} = &GetNextBYTE;
	$rtvchannel{episodelen} = &GetNextBYTE;
	$rtvchannel{descriptionlen} = &GetNextBYTE;
	$rtvchannel{actorlen} = &GetNextBYTE;
	$rtvchannel{guestlen} = &GetNextBYTE;
	$rtvchannel{suzukilen} = &GetNextBYTE;
	$rtvchannel{producerlen} = &GetNextBYTE;
	$rtvchannel{directorlen} = &GetNextBYTE;
	$rtvchannel{description} = &GetRaw(228);
	$rtvchannel{ivsstatus} = &GetNextDWORD;
	$rtvchannel{guideid} = &GetNextDWORD;	
	$rtvchannel{downloadid} = &GetNextDWORD;	
	$rtvchannel{timessent} = &GetNextDWORD;
	$rtvchannel{seconds} = &GetNextDWORD;
	$rtvchannel{gopcount} = &GetNextDWORD;
	$rtvchannel{gophighest} = &GetNextDWORD;
	$rtvchannel{goplast} = &GetNextDWORD;
	$rtvchannel{checkpointed} = &GetNextDWORD;
	$rtvchannel{intact} = &GetNextDWORD;
	$rtvchannel{upgradeflag} = &GetNextDWORD;
	$rtvchannel{instance} = &GetNextDWORD;
	$rtvchannel{unused} = &GetNextWORD;
	$rtvchannel{beforepadding} = &GetNextBYTE;
	$rtvchannel{afterpadding} = &GetNextBYTE;
	$rtvchannel{indexsize} = &GetRaw(8);
	$rtvchannel{mpegsize} = &GetRaw(8);
	$rtvchannel{reserved} = &GetRaw(68);
	$rtvchannel{themeflags} = &GetNextDWORD;
	$rtvchannel{suzukiid} = &GetNextDWORD;
	$rtvchannel{thememinutes} = &GetNextDWORD;
	$rtvchannel{searchstring} = &GetSZ(48);
	$rtvchannel{created} = &GetNextDWORD;
	$rtvchannel{category} = &GetNextDWORD; # 2^category number
	$rtvchannel{channeltype} = &GetNextDWORD;
	$rtvchannel{quality} = &GetNextDWORD;
	$rtvchannel{stored} = &GetNextDWORD;
	$rtvchannel{keep} = &GetNextDWORD;
	$rtvchannel{daysofweek} = &GetNextBYTE;
	$rtvchannel{afterpadding} = &GetNextBYTE;
	$rtvchannel{beforepadding} = &GetNextBYTE;
	$rtvchannel{channelflags} = &GetNextBYTE;
	$rtvchannel{timereserved} = &GetRaw(8);
	$rtvchannel{showlabel} = &GetSZ(48);
	$rtvchannel{unknown1} = &GetNextDWORD;
	$rtvchannel{unknown2} = &GetNextDWORD;
	$rtvchannel{unknown3} = &GetNextDWORD;
	$rtvchannel{unknown4} = &GetNextDWORD;
	$rtvchannel{unknown5} = &GetNextDWORD;
	$rtvchannel{unknown6} = &GetNextDWORD;
	$rtvchannel{unknown7} = &GetNextDWORD;
	$rtvchannel{unknown8} = &GetNextDWORD;
	$rtvchannel{allocatedspace} = &GetRaw(8);
	$rtvchannel{unknown9} = &GetNextDWORD;
	$rtvchannel{unknown10} = &GetNextDWORD;
	$rtvchannel{unknown11} = &GetNextDWORD;
	$rtvchannel{unknown12} = &GetNextDWORD;

	return 1;
	
}

#----------------------------------------------------------------------------------------
sub getRTVChannel43($) {
	# Get RTV ReplayChannel #
	#
	# For Channel Size: 624
	#
	#--------------------------------------------------------------------------------

	my $rtvchannel = int shift;

	#--------------------------------------------------------------------------------
	# Set Base
	#--------------------------------------------------------------------------------

	$guideptr = $guideheader{channeloffset} - 624;

	$guideptr = $guideptr + ($rtvchannel * 624);

	$rtvchannel{channeltype} = &GetNextDWORD;
	$rtvchannel{quality} = &GetNextDWORD;
	$rtvchannel{allocatedspace} = &GetRaw(8);
	$rtvchannel{keep} = &GetNextDWORD;
	$rtvchannel{stored} = &GetNextDWORD;
	$rtvchannel{daysofweek} = &GetNextBYTE;
	$rtvchannel{afterpadding} = &GetNextBYTE;
	$rtvchannel{beforepadding} = &GetNextBYTE;
	$rtvchannel{channelflags} = &GetNextBYTE;
	$rtvchannel{category} = &GetNextDWORD; # 2^category number
	$rtvchannel{created} = &GetNextDWORD;
	$rtvchannel{unknown1} = &GetNextDWORD;
	$rtvchannel{unknown2} = &GetNextDWORD;
	$rtvchannel{unknown3} = &GetNextDWORD;
	$rtvchannel{unknown4} = &GetNextDWORD;
	$rtvchannel{unknown5} = &GetNextDWORD;
	$rtvchannel{unknown6} = &GetNextDWORD;
	$rtvchannel{unknown7} = &GetNextDWORD;
	$rtvchannel{secondsallocated} = &GetNextDWORD;
	$rtvchannel{showlabel} = &GetSZ(48);
	$rtvchannel{created} = &GetNextDWORD;
	$rtvchannel{recorded} = &GetNextDWORD;
	$rtvchannel{inputsource} = &GetNextDWORD;
	$rtvchannel{quality} = &GetNextDWORD;
	$rtvchannel{guaranteed} = &GetNextDWORD;
	$rtvchannel{playbackflags} = &GetNextDWORD;
	$rtvchannel{channelstructsize} = &GetNextDWORD;
	$rtvchannel{usetuner} = &GetNextDWORD;
	$rtvchannel{isvalid} = &GetNextDWORD;
	$rtvchannel{tmsid} = &GetNextDWORD;
	$rtvchannel{channel} = &GetNextWORD;
	$rtvchannel{device} = &GetNextBYTE;
	$rtvchannel{tier} = &GetNextBYTE;
	$rtvchannel{channelname} = &GetSZ(16);
	$rtvchannel{channellabel} = &GetSZ(32);
	$rtvchannel{headend} = &GetSZ(8);
	$rtvchannel{channelindex} = &GetNextDWORD;
	$rtvchannel{programstructsize} = &GetNextDWORD;
	$rtvchannel{autorecord} = &GetNextDWORD;
	$rtvchannel{isvalid} = &GetNextDWORD;
	$rtvchannel{tuning} = &GetNextDWORD;
	$rtvchannel{programflags} = &GetNextDWORD;
	$rtvchannel{eventtime} = &GetNextDWORD;
	$rtvchannel{programtmsid} = &GetNextDWORD;
	$rtvchannel{minutes} = &GetNextWORD;
	$rtvchannel{genre1} = &GetNextBYTE;
	$rtvchannel{genre2} = &GetNextBYTE;
	$rtvchannel{genre3} = &GetNextBYTE;
	$rtvchannel{genre4} = &GetNextBYTE;
	$rtvchannel{reclen} = &GetNextWORD;
	$rtvchannel{titlelen} = &GetNextBYTE;
	$rtvchannel{episodelen} = &GetNextBYTE;
	$rtvchannel{descriptionlen} = &GetNextBYTE;
	$rtvchannel{actorlen} = &GetNextBYTE;
	$rtvchannel{guestlen} = &GetNextBYTE;
	$rtvchannel{suzukilen} = &GetNextBYTE;
	$rtvchannel{producerlen} = &GetNextBYTE;
	$rtvchannel{directorlen} = &GetNextBYTE;
	$rtvchannel{description} = &GetRaw(228);
	$rtvchannel{ivsstatus} = &GetNextDWORD;
	$rtvchannel{guideid} = &GetNextDWORD;	
	$rtvchannel{downloadid} = &GetNextDWORD;	
	$rtvchannel{timessent} = &GetNextDWORD;
	$rtvchannel{seconds} = &GetNextDWORD;
	$rtvchannel{gopcount} = &GetNextDWORD;
	$rtvchannel{gophighest} = &GetNextDWORD;
	$rtvchannel{goplast} = &GetNextDWORD;
	$rtvchannel{checkpointed} = &GetNextDWORD;
	$rtvchannel{intact} = &GetNextDWORD;
	$rtvchannel{upgradeflag} = &GetNextDWORD;
	$rtvchannel{instance} = &GetNextDWORD;
	$rtvchannel{unused} = &GetNextWORD;
	$rtvchannel{beforepadding} = &GetNextBYTE;
	$rtvchannel{afterpadding} = &GetNextBYTE;
	$rtvchannel{indexsize} = &GetRaw(8);
	$rtvchannel{mpegsize} = &GetRaw(8);
	$rtvchannel{themeflags} = &GetNextDWORD;
	$rtvchannel{suzukiid} = &GetNextDWORD;
	$rtvchannel{thememinutes} = &GetNextDWORD;
	$rtvchannel{searchstring} = &GetSZ(52);

	return 1;
	
}

#----------------------------------------------------------------------------------------
sub getRTVShow {
	#
	# Get RTV ReplayShow #
	#
	# For Channel Size: 512
	#
	#--------------------------------------------------------------------------------

	my $rtvshow = int shift;

	if ($debug) {
		print "getRTVShow::Searching for # ($rtvshow)\n";
		print "getRTVShow::checking $guideheader{snapshotversion}\n";
	}

	if ($rtvshow < 1) {
		if ($debug) {
			print "No Show Requested($rtvshow)\n";
		}
		return 0;
	}

	if ($guideptr >= $guideheader{snapshotsize}) {
		if ($debug) {
			print "At or Past End $guideptr >= $guideheader{snapshotsize}\n";
		}
		return 0;
	}

	if (($guideheader{snapshotversion} == 2) && ($guideheader{osversion} == 0))  {
		&getRTVShow50($rtvshow);
		$rtvshow{desc_block} = &ParseDescBlock;
		return 1;
	}

	if (($guideheader{snapshotversion} == 1) && ($guideheader{osversion} == 5))  {
		&getRTVShow45($rtvshow);
		$rtvshow{desc_block} = &ParseDescBlock;
		return 1;
	}

	if (($guideheader{snapshotversion} == 1) && ($guideheader{osversion} == 3))  {
		&getRTVShow43($rtvshow);
		$rtvshow{desc_block} = &ParseDescBlock;
		return 1;
	}

	return 0;
}

#----------------------------------------------------------------------------------------
sub ParseDescBlock {
	#
	# Parse the description/extended data block of a rtvshow
	#
	#--------------------------------------------------------------------------------

	my $ctr = 0;
	my $return_block = "";
	my $ext_data = "";
	my $cc = "";
	my $stereo = "";
	my $repeat = "";
	my $sap = "";
	my $lbx = "";
	my $ppv = "";
	my $movie = "";
	my $rating = "";
	my $movieblock = "";
	my $mpaa = "";
	my $stars = "";
	my $starsicon = "";
	my $year = "";
	my $part = 0;
	my $maxpart = 0;

	if ($rtvshow{programflags} & 1) {
		$cc = "CC";
	}

	if ($rtvshow{programflags} & 2) {
		$stereo = "Stereo";
	}

	if ($rtvshow{programflags} & 4) {
		$repeat = "Repeat";
	}

	if ($rtvshow{programflags} & 8) {
		$sap = "SAP";
	}

	if ($rtvshow{programflags} & 16) {
		$lbx = "Letterboxed";
	}
	

	if ($rtvshow{programflags} & 32) {
		#
		# Skip MovieInfo
		#
		$movieblock = substr($rtvshow{description},0,7);
		$mpaa = unpack("n",substr($movieblock,0,2));
		$stars = unpack("n",substr($movieblock,2,2));
		$year = unpack("n",substr($movieblock,4,2));

		$stars = int $stars / 10;

		$starsicon = substr("*********",0,$stars);

		if ($stars % 10) {
			$starsicon .= "1/2";
		}

		if ($mpaa & 1) {
			$rating = "AO";
		}

		if ($mpaa & 2) {
			$rating = "G";
		}

		if ($mpaa & 4) {
			$rating = "NC-17";
		}

		if ($mpaa & 8) {
			$rating = "NR";
		}

		if ($mpaa & 16) {
			$rating = "PG";
		}

		if ($mpaa & 32) {
			$rating = "PG-13";
		}

		if ($mpaa & 64) {
			$rating = "R";
		}
	
		$movie = "$starsicon,$rating,$year";
		$ctr += 4;
	}

	if ($rtvshow{programflags} & 64) {
		#
		# Skip PartsInfo
		#
		
		$part = unpack("n",substr($rtvshow{description},0,2));
		$maxpart = unpack("n",substr($rtvshow{description},2,2));
		$ctr += 2;
	}

	if ($rtvshow{programflags} & 128) {
		#
		# Skip PartsInfo
		#
		$ppv = "PPV";
	}

	if ($rtvshow{programflags} & 32768) {
		$rating = "TV-Y";
	}

	if ($rtvshow{programflags} & 65536) {
		$rating = "TV-Y7";
	}

	if ($rtvshow{programflags} & 4096) {
		$rating = "TV-G";
	}

	if ($rtvshow{programflags} & 16384) {
		$rating = "TV-PG";
	}

	if ($rtvshow{programflags} & 8192) {
		$rating = "TV-MA";
	}



	$ext_data = "$cc;$stereo;$repeat;$sap;$lbx;$movie;$rating";

	my $description_block = substr($rtvshow{description},$ctr,$rtvshow{reclen});

	my $title = substr($description_block,$ctr,$rtvshow{titlelen}-1);
	$ctr += $rtvshow{titlelen};

	my $episode = substr($description_block,$ctr,$rtvshow{episodelen}-1);
	$ctr += $rtvshow{episodelen};

	my $description = substr($description_block,$ctr,$rtvshow{descriptionlen}-1);
	$ctr += $rtvshow{descriptionlen};

	if ($part > 0) {
		$description .= " (Part $part of $maxpart)";
	}

	my $actors = substr($description_block,$ctr,$rtvshow{actorlen}-1);
	$ctr += $rtvshow{actorlen};

	my $guests = substr($description_block,$ctr,$rtvshow{guestlen}-1);
	$ctr += $rtvshow{guestlen};

	my $suzuki = substr($description_block,$ctr,$rtvshow{suzukilen}-1);
	$ctr += $rtvshow{suzukilen};

	my $producers = substr($description_block,$ctr,$rtvshow{producerlen}-1);
	$ctr += $rtvshow{producerlen};

	my $directors = substr($description_block,$ctr,$rtvshow{directorlen}-1);
	$ctr += $rtvshow{directorlen};

	$return_block = "$title|$episode|$description|$actors|$guests|$suzuki|$producers|$directors|$ext_data";

	return $return_block;
}

#----------------------------------------------------------------------------------------
sub getRTVShow50($){
	#
	# Get RTV ReplayShow #
	#
	# For Channel Size: 512
	#
	#--------------------------------------------------------------------------------

	my $rtvshow = int shift;

	#--------------------------------------------------------------------------------
	# Set Base
	#--------------------------------------------------------------------------------

	$guideptr = $guideheader{showoffset} - 512;

	$guideptr = $guideptr + ($rtvshow * 512);

	$rtvshow{created} = &GetNextDWORD;
	$rtvshow{recorded} = &GetNextDWORD;
	$rtvshow{inputsource} = &GetNextDWORD;
	$rtvshow{quality} = &GetNextDWORD;
	$rtvshow{guaranteed} = &GetNextDWORD;
	$rtvshow{playbackflags} = &GetNextDWORD;
	$rtvshow{channelstructsize} = &GetNextDWORD;
	$rtvshow{usetuner} = &GetNextDWORD;
	$rtvshow{isvalid} = &GetNextDWORD;
	$rtvshow{tmsid} = &GetNextDWORD;
	$rtvshow{channel} = &GetNextWORD;
	$rtvshow{device} = &GetNextBYTE;
	$rtvshow{tier} = &GetNextBYTE;
	$rtvshow{channelname} = &GetSZ(16);
	$rtvshow{channellabel} = &GetSZ(32);
	$rtvshow{headend} = &GetSZ(8);
	$rtvshow{channelindex} = &GetNextDWORD;
	$rtvshow{programstructsize} = &GetNextDWORD;
	$rtvshow{autorecord} = &GetNextDWORD;
	$rtvshow{isvalid} = &GetNextDWORD;
	$rtvshow{tuning} = &GetNextDWORD;
	$rtvshow{programflags} = &GetNextDWORD;
	$rtvshow{eventtime} = &GetNextDWORD;
	$rtvshow{programtmsid} = &GetNextDWORD;
	$rtvshow{minutes} = &GetNextWORD;
	$rtvshow{genre1} = &GetNextBYTE;
	$rtvshow{genre2} = &GetNextBYTE;
	$rtvshow{genre3} = &GetNextBYTE;
	$rtvshow{genre4} = &GetNextBYTE;
	$rtvshow{reclen} = &GetNextWORD;
	$rtvshow{titlelen} = &GetNextBYTE;
	$rtvshow{episodelen} = &GetNextBYTE;
	$rtvshow{descriptionlen} = &GetNextBYTE;
	$rtvshow{actorlen} = &GetNextBYTE;
	$rtvshow{guestlen} = &GetNextBYTE;
	$rtvshow{suzukilen} = &GetNextBYTE;
	$rtvshow{producerlen} = &GetNextBYTE;
	$rtvshow{directorlen} = &GetNextBYTE;
	$rtvshow{description} = &GetRaw(228);
	$rtvshow{ivsstatus} = &GetNextDWORD;
	$rtvshow{guideid} = &GetNextDWORD;	
	$rtvshow{downloadid} = &GetNextDWORD;	
	$rtvshow{timessent} = &GetNextDWORD;
	$rtvshow{seconds} = &GetNextDWORD;
	$rtvshow{gopcount} = &GetNextDWORD;
	$rtvshow{gophighest} = &GetNextDWORD;
	$rtvshow{goplast} = &GetNextDWORD;
	$rtvshow{checkpointed} = &GetNextDWORD;
	$rtvshow{intact} = &GetNextDWORD;
	$rtvshow{upgradeflag} = &GetNextDWORD;
	$rtvshow{instance} = &GetNextDWORD;
	$rtvshow{unused} = &GetNextWORD;
	$rtvshow{beforepadding} = &GetNextBYTE;
	$rtvshow{afterpadding} = &GetNextBYTE;
	$rtvshow{indexsize} = &GetRaw(8);
	$rtvshow{mpegsize} = &GetRaw(8);
	$rtvshow{reserved} = &GetRaw(68);


	return 1;
	
}


#----------------------------------------------------------------------------------------
sub getRTVShow45($){
	#
	# THIS IS UNTESTED
	#
	#
	# Get RTV ReplayShow #
	#
	# For Channel Size: 512 (4.5)
	#
	#--------------------------------------------------------------------------------

	my $rtvshow = int shift;

	#--------------------------------------------------------------------------------
	# Set Base
	#--------------------------------------------------------------------------------

	$guideptr = $guideheader{showoffset} - 512;

	$guideptr = $guideptr + ($rtvshow * 512);

	$rtvshow{created} = &GetNextDWORD;
	$rtvshow{recorded} = &GetNextDWORD;
	$rtvshow{inputsource} = &GetNextDWORD;
	$rtvshow{quality} = &GetNextDWORD;
	$rtvshow{guaranteed} = &GetNextDWORD;
	$rtvshow{playbackflags} = &GetNextDWORD;
	$rtvshow{channelstructsize} = &GetNextDWORD;
	$rtvshow{usetuner} = &GetNextDWORD;
	$rtvshow{isvalid} = &GetNextDWORD;
	$rtvshow{tmsid} = &GetNextDWORD;
	$rtvshow{channel} = &GetNextWORD;
	$rtvshow{device} = &GetNextBYTE;
	$rtvshow{tier} = &GetNextBYTE;
	$rtvshow{channelname} = &GetSZ(16);
	$rtvshow{channellabel} = &GetSZ(32);
	$rtvshow{headend} = &GetSZ(8);
	$rtvshow{channelindex} = &GetNextDWORD;
	$rtvshow{programstructsize} = &GetNextDWORD;
	$rtvshow{autorecord} = &GetNextDWORD;
	$rtvshow{isvalid} = &GetNextDWORD;
	$rtvshow{tuning} = &GetNextDWORD;
	$rtvshow{programflags} = &GetNextDWORD;
	$rtvshow{eventtime} = &GetNextDWORD;
	$rtvshow{programtmsid} = &GetNextDWORD;
	$rtvshow{minutes} = &GetNextWORD;
	$rtvshow{genre1} = &GetNextBYTE;
	$rtvshow{genre2} = &GetNextBYTE;
	$rtvshow{genre3} = &GetNextBYTE;
	$rtvshow{genre4} = &GetNextBYTE;
	$rtvshow{reclen} = &GetNextWORD;
	$rtvshow{titlelen} = &GetNextBYTE;
	$rtvshow{episodelen} = &GetNextBYTE;
	$rtvshow{descriptionlen} = &GetNextBYTE;
	$rtvshow{actorlen} = &GetNextBYTE;
	$rtvshow{guestlen} = &GetNextBYTE;
	$rtvshow{suzukilen} = &GetNextBYTE;
	$rtvshow{producerlen} = &GetNextBYTE;
	$rtvshow{directorlen} = &GetNextBYTE;
	$rtvshow{description} = &GetRaw(228);
	$rtvshow{ivsstatus} = &GetNextDWORD;
	$rtvshow{guideid} = &GetNextDWORD;	
	$rtvshow{downloadid} = &GetNextDWORD;	
	$rtvshow{timessent} = &GetNextDWORD;
	$rtvshow{seconds} = &GetNextDWORD;
	$rtvshow{gopcount} = &GetNextDWORD;
	$rtvshow{gophighest} = &GetNextDWORD;
	$rtvshow{goplast} = &GetNextDWORD;
	$rtvshow{checkpointed} = &GetNextDWORD;
	$rtvshow{intact} = &GetNextDWORD;
	$rtvshow{upgradeflag} = &GetNextDWORD;
	$rtvshow{instance} = &GetNextDWORD;
	$rtvshow{unused} = &GetNextWORD;
	$rtvshow{beforepadding} = &GetNextBYTE;
	$rtvshow{afterpadding} = &GetNextBYTE;
	$rtvshow{indexsize} = &GetRaw(8);
	$rtvshow{mpegsize} = &GetRaw(8);
	$rtvshow{reserved} = &GetRaw(68);


	return 1;
	
}

#----------------------------------------------------------------------------------------
sub getRTVShow43($){
	#
	# THIS IS UNTESTED
	#
	#
	# Get RTV ReplayShow #
	#
	# For Channel Size: 444 (4.3)
	#
	#--------------------------------------------------------------------------------

	my $rtvshow = int shift;

	#--------------------------------------------------------------------------------
	# Set Base
	#--------------------------------------------------------------------------------

	$guideptr = $guideheader{showoffset} - 444;

	$guideptr = $guideptr + ($rtvshow * 444);

	$rtvshow{created} = &GetNextDWORD;
	$rtvshow{recorded} = &GetNextDWORD;
	$rtvshow{inputsource} = &GetNextDWORD;
	$rtvshow{quality} = &GetNextDWORD;
	$rtvshow{guaranteed} = &GetNextDWORD;
	$rtvshow{playbackflags} = &GetNextDWORD;
	$rtvshow{channelstructsize} = &GetNextDWORD;
	$rtvshow{usetuner} = &GetNextDWORD;
	$rtvshow{isvalid} = &GetNextDWORD;
	$rtvshow{tmsid} = &GetNextDWORD;
	$rtvshow{channel} = &GetNextWORD;
	$rtvshow{device} = &GetNextBYTE;
	$rtvshow{tier} = &GetNextBYTE;
	$rtvshow{channelname} = &GetSZ(16);
	$rtvshow{channellabel} = &GetSZ(32);
	$rtvshow{headend} = &GetSZ(8);
	$rtvshow{channelindex} = &GetNextDWORD;
	$rtvshow{programstructsize} = &GetNextDWORD;
	$rtvshow{autorecord} = &GetNextDWORD;
	$rtvshow{isvalid} = &GetNextDWORD;
	$rtvshow{tuning} = &GetNextDWORD;
	$rtvshow{programflags} = &GetNextDWORD;
	$rtvshow{eventtime} = &GetNextDWORD;
	$rtvshow{programtmsid} = &GetNextDWORD;
	$rtvshow{minutes} = &GetNextWORD;
	$rtvshow{genre1} = &GetNextBYTE;
	$rtvshow{genre2} = &GetNextBYTE;
	$rtvshow{genre3} = &GetNextBYTE;
	$rtvshow{genre4} = &GetNextBYTE;
	$rtvshow{reclen} = &GetNextWORD;
	$rtvshow{titlelen} = &GetNextBYTE;
	$rtvshow{episodelen} = &GetNextBYTE;
	$rtvshow{descriptionlen} = &GetNextBYTE;
	$rtvshow{actorlen} = &GetNextBYTE;
	$rtvshow{guestlen} = &GetNextBYTE;
	$rtvshow{suzukilen} = &GetNextBYTE;
	$rtvshow{producerlen} = &GetNextBYTE;
	$rtvshow{directorlen} = &GetNextBYTE;
	$rtvshow{description} = &GetRaw(228);
	$rtvshow{ivsstatus} = &GetNextDWORD;
	$rtvshow{guideid} = &GetNextDWORD;	
	$rtvshow{downloadid} = &GetNextDWORD;	
	$rtvshow{timessent} = &GetNextDWORD;
	$rtvshow{seconds} = &GetNextDWORD;
	$rtvshow{gopcount} = &GetNextDWORD;
	$rtvshow{gophighest} = &GetNextDWORD;
	$rtvshow{goplast} = &GetNextDWORD;
	$rtvshow{checkpointed} = &GetNextDWORD;
	$rtvshow{intact} = &GetNextDWORD;
	$rtvshow{upgradeflag} = &GetNextDWORD;
	$rtvshow{instance} = &GetNextDWORD;
	$rtvshow{unused} = &GetNextWORD;
	$rtvshow{beforepadding} = &GetNextBYTE;
	$rtvshow{afterpadding} = &GetNextBYTE;
	$rtvshow{indexsize} = &GetRaw(8);
	$rtvshow{mpegsize} = &GetRaw(8);

	return 1;
	
}


#----------------------------------------------------------------------------------------
sub getCategory {
	my $lookfor = int shift;
	my $replayid = int shift;
	my ($categorycount,$categories) = split(/\|/,$rtv_categories{$replayid});
	my $c_num = 0;
	my $c_text = "";
	my $retcode = "";

	if ($debug) {
		print "getCategory::Looking for \"$lookfor\" on unit \"$replayid\"\n";
		print "getCategory::$categorycount categories ($categories)\n";
	}

	for ( split /\;/, $categories ) {
		/\;/;
		my $categoryentry = $_;
		my ($c_num,$c_text) = split(/\,/,$categoryentry);
		$c_num = 2 ** int $c_num;
		if ($debug) {
			print "getCategory::Comparing \"$c_num\" with \"$lookfor\" ($c_text)\n";
		}

		if ($c_num == $lookfor) { 
			$retcode = $c_text;
		}
	}

	if (length($retcode) == 0) {
		$retcode = "All Shows";
	}
	
	if ($debug) {
		print "getCategory::returning \"$retcode\"\n";
	}

	return $retcode;
	
}

#----------------------------------------------------------------------------------------
sub getShowAndParent {
	my $rtvshow = shift;
	my $retcode = 0;
	
	parseShow($rtvshow);

	my $channelnum = findChannel($show_rtvcreated,$show_replayid);

	if ($channelnum) {
		parseChannel($rtvevent[$channelnum]);
		$show_category = getCategory($chan_rtvcategory,$show_replayid);
		$retcode = 1;
	}else{
		$retcode = 0;
	}

	return $retcode;
}

#----------------------------------------------------------------------------------------
sub findChannel {

	my $rtv_event = int shift;
	my $rtv_id = int shift;
	my $event_num = 0;
	my $status = 0;
	my $ctr = 0;
	
	if ($debug) {
		print "findChannel::Starting($rtv_event,$rtv_id)\n";
	}

	if ($debug) {
		print "findChannel::Searching\n";
	}
		
	do {
		$ctr++;
		if (length($rtvevent[$ctr]) > 0) {
			parseChannel($rtvevent[$ctr]);
			if ($chan_replayid == $rtv_id) {
				if ($chan_rtvcreate == $rtv_event) {
					$event_num = $ctr;
					$status = 1;
					if ($debug) {
						print "findChannel::found event ($ctr)\n";
					}

				}
			}
		}else{
			$status = 1;
		}

	} while $status == 0;

	if ($debug) {
		print "findChannel::exiting ($event_num,$status)\n";
	}
	
	
	return $event_num;
}

#----------------------------------------------------------------------------------------
sub parseChannel {
	my $rtvchannel = shift;

	undef $chan_replayid;
	undef $chan_rtveventtime;
	undef $chan_guaranteed;
	undef $chan_channeltype;
	undef $chan_daysofweek;
	undef $chan_channelflags;
	undef $chan_beforepadding;
	undef $chan_afterpadding;
	undef $chan_showlabel;
	undef $chan_channelname;	
	undef $chan_themeflags;	
	undef $chan_themestring;
	undef $chan_thememinutes;
	undef $chan_rtvcreate;
	undef $chan_rtvcategory;
	undef $chan_keep;
	undef $chan_norepeats;
	undef $chan_minutes;

	($chan_replayid,$chan_rtvcreate,$chan_rtveventtime,$chan_guaranteed,$chan_channeltype,$chan_daysofweek,$chan_channelflags,$chan_beforepadding,$chan_afterpadding,$chan_showlabel,$chan_channelname,$chan_themeflags,$chan_themestring,$chan_thememinutes,$chan_rtvcategory,$chan_keep,$chan_norepeats,$chan_minutes) = split(/\|/,$rtvchannel);

	$chan_categoryname = getCategory($chan_rtvcreate,$chan_replayid);

	return 1;
}


#----------------------------------------------------------------------------------------
sub parseShow{
	my $rtvshow = shift;

	undef $show_replayid;
	undef $show_rtvcreated;
	undef $show_rtvrecorded;
	undef $show_inputsource;
	undef $show_quality;
	undef $show_guaranteed;
	undef $show_tmsid;
	undef $show_channel;
	undef $show_channelname;	
	undef $show_channellabel;	
	undef $show_tuning;	
	undef $show_rtveventtime;	
	undef $show_programtmsid;	
	undef $show_rtvminutes;	
	undef $show_rtvtitle;	
	undef $show_rtvepisode;	
	undef $show_rtvdescription;	
	undef $show_rtvactors;	
	undef $show_rtvguests;	
	undef $show_rtvsuzuki;	
	undef $show_rtvproducers;	
	undef $show_rtvdirectors;	
	undef $show_ext_data;	
	undef $show_beforepadding;	
	undef $show_afterpadding;	
	undef $show_rtvcc;	
	undef $show_rtvstereo;	
	undef $show_rtvrepeat;	
	undef $show_rtvsap;	
	undef $show_rtvlbx;	
	undef $show_rtvmovie;	
	undef $show_category;
	undef $show_rating;

	($show_replayid,$show_rtvcreated,$show_rtvrecorded,$show_inputsource,$show_quality,$show_guaranteed,$show_tmsid,$show_channel,$show_channelname,$show_channellabel,$show_tuning,$show_rtveventtime,$show_programtmsid,$show_rtvminutes,$show_rtvtitle,$show_rtvepisode,$show_rtvdescription,$show_rtvactors,$show_rtvguests,$show_rtvsuzuki,$show_rtvproducers,$show_rtvdirectors,$show_ext_data,$show_beforepadding,$show_afterpadding) = split(/\|/,$rtvshow);
	($show_rtvcc,$show_rtvstereo,$show_rtvrepeat,$show_rtvsap,$show_rtvlbx,$show_rtvmovie,$show_rating) = split(/;/,$show_ext_data);
	

	return 1;
}

#-------------------------------------------------------------------------------------
sub processSlotResponse {
	#
	# Process returned slot_data, patch in quality flag (not passed back on non
	# manual recordings for some reason).
	#
	# Expects slot_data,quality
	# Returns recordrequest for recordshow
	#
	#--------------------------------------------

	my $slotdata = substr(shift,0,144);
	my $quality = int shift;
	my $recordrequest = "";
	my $specialdebug = 1;

	$recordrequest = substr($slotdata,0,48);
	$recordrequest .= converthex($quality,$DWORD);
	$recordrequest .= substr($slotdata,56);

	if (($debug) || ($specialdebug)) {
		writeDebug("processSlotResponse returning $recordrequest");
	}

	return $recordrequest;

}

#-----------------------------------------------------------------
sub recordShow {
	#
	# Makes a RecordShow Request to Specified DVR
	#
	# Parameters: Replay FQDN or IP, RecordRequest HexString
	#
	# Returns: Response Code
	#
	# Codes: 2 (Debug), 1 (Success), 0 (Failed)
	#
	#---------------------------------------------------------
	my $replaytv = shift;
	my $recordrequest = shift;
	my $returndata = "";
	my $replaycmd = "";
	my $specialdebug = 1;


	$replaycmd = "http://$replaytv/http_replay_guide-record_show?record_request=$recordrequest";

	if ($RemoteAddress eq "") {
		my $RemoteAddress = "127.0.0.1";
	}

	my $h = HTTP::Headers->new(
       		Host         => '$RemoteAddress:80',
       		Accept_Coding => 'gzip');

	if ($debug_supress_show_request) {
		if ($debug) {
			writeDebug("record_request: $recordrequest");
		}
		return 2;
	}

	$ua = LWP::UserAgent->new;
	$request = HTTP::Request->new(GET => $replaycmd, $h);
	$response = $ua->request($request);


	if (($debug) || ($specialdebug)) {
		writeDebug("recordShow http_replay_guide-recordshow returned: $response->content");
	}

	
	if ($response->is_success) {
			if ($response->content =~ /record_result=0x0/) {	# Cheesy
				$returndata = 1;
			}
			else
			{
				$returndata = 0;
			}			
		     	
		} else {
			$returndata = -1;
	}

	if (($debug) || ($specialdebug)) {
		writeDebug("recordShow returning $returndata");
	}

	return $returndata;
}

#-----------------------------------------------------------------
sub getManualSlotRequest {
	#
	# Makes a SlotRequest to Specified DVR
	#
	# Parameters: Replay FQDN or IP, SlotData HexString
	#
	# Returns: Numeric Code on Failure or 
	#          Returned SlotData Struct
	#
	#
	# Codes: 2 (Debug), -1 (Connect Fail), 0 (No Slots)
	#
	#---------------------------------------------------------
	my $replaytv = shift;
	my $slotdata = shift;
	my $returndata = "";
	my $replaycmd = "";
	my $manual_record_struct_size = 224;
	my $specialdebug = 1;

	$replaycmd = "http://$replaytv/http_replay_guide-get_manual_record_slots?slot_data=$slotdata";

	if ($RemoteAddress eq "") {
		my $RemoteAddress = "127.0.0.1";
	}

	my $h = HTTP::Headers->new(
       		Host         => '$RemoteAddress:80',
       		Accept_Coding => 'gzip');

	if ($debug_supress_slot_request) {
		return 2;
	}

	if (($debug) || ($specialdebug)) {
		writeDebug("getManualSlotRequest Requesting Slot: $slotdata");
	}

	if (length($slotdata) != $manual_record_struct_size) {
		writeDebug("getManualSlotRequest Error: SlotData incorrect length.  $manual_record_struct_size !" . length($slotdata));
		return 0;
	}


	$ua = LWP::UserAgent->new;
	$request = HTTP::Request->new(GET => $replaycmd, $h);
	$response = $ua->request($request);

	if (($debug) || ($specialdebug)) {
		my $raw_response = $response->content;
		writeDebug("getManualSlotRequest http_replay_guide-get_manual_record_slots returned: $raw_response");
	}

	if ($response->is_success) {
			if ($response->content =~ /n_slots=0x0/) {		# Cheesy
				$returndata = 0;
			}
			else
			{
				$returndata = substr($response->content,31);	# Cheesy
			}			
		     	
		} else {
			$returndata = -1;

	}

	if (($debug) || ($specialdebug)) {
		writeDebug("getManualSlotRequest returning: $returndata");
	}


	if (($debug) || ($specialdebug)) {
		writeDebug("getManualSlotRequest exiting");
	}

	return $returndata;
}

#-----------------------------------------------------------------
sub getSlotRequest {
	#
	# Makes a SlotRequest to Specified DVR
	#
	# Parameters: Replay FQDN or IP, Program HexString, RecordRequest HexString
	#
	# Returns: Numeric Code on Failure or 
	#          Returned SlotData Struct
	#
	#
	# Codes: 2 (Debug), -1 (Connect Fail), 0 (No Slots)
	#
	#---------------------------------------------------------

	my $replaytv = shift;
	my $program = shift;
	my $recordrequest = shift;
	my $returndata = "";
	my $replaycmd = "";
	my $program_struct_size = 544;
	my $record_request_struct_size = 144;
	my $manual_record_struct_size = 224;

	my $specialdebug = 1;

	$replaycmd = "http://$replaytv/http_replay_guide-get_record_slots?time_based=0x1&program=$program&record_request=$recordrequest";

	if ($RemoteAddress eq "") {
		my $RemoteAddress = "127.0.0.1";
	}

	my $h = HTTP::Headers->new(
       		Host         => '$RemoteAddress:80',
       		Accept_Coding => 'gzip');


	if ($debug_supress_slot_request) {
		return 2;
	}

	if (($debug) || ($specialdebug)) {
		writeDebug("getSlotRequest Program: $program");
	}

	if (($debug) || ($specialdebug)) {
		writeDebug("getSlotRequest Request: $recordrequest");
	}

	if (length($program) != $program_struct_size) {
		writeDebug("getSlotRequest Error: Program structure incorrect length. $program_struct_size!" . length($program));
		return 0;
	}


	if (length($recordrequest) != $record_request_struct_size) {
		writeDebug("getSlotRequest Error: Record request incorrect length.  $record_request_struct_size!" . length($recordrequest));
		return 0;
	}

	$ua = LWP::UserAgent->new;
	$request = HTTP::Request->new(GET => $replaycmd, $h);
	$response = $ua->request($request);

	if (($debug) || ($specialdebug)) {
		writeDebug("getSlotRequest http_replay_guide-get_record_slots returned: $response->content");
	}

	if ($response->is_success) {
			if ($response->content =~ /n_slots=0x0/) {		# Cheesy
				$returndata = 0;
			}
			else
			{
				$returndata = substr($response->content,31);	# Cheesy
			}			
		     	
		} else {
			$returndata = -1;

	}

	if (($debug) || ($specialdebug)) {
		writeDebug("getSlotRequest returned: $returndata");
	}

	return $returndata;
}

#-----------------------------------------------------------------
sub parseSlotData {
	#
	# Parse Slot Data
	#
	# Parameters: Slot_Data Response (224 chars)
	#
	# Returns: Printable String
	#
	#---------------------------------------------------------

	my $slotdata = shift;
	my $parsedstring = "";
	my $specialdebug = 1;

	my $year = hex(substr($slotdata,8,4));
	my $month = hex(substr($slotdata,12,4));
	my $day = hex(substr($slotdata,16,4));
	my $hour = hex(substr($slotdata,20,4));
	my $minute = hex(substr($slotdata,24,4));
	my $minutes = hex(substr($slotdata,40,8));
	my $textstring = &decodehex(substr($slotdata,152));
	my $timestamp = "";
	my $eventtime =	timegm(0,$minute,$hour,$day,$month-1,$year);
	# my $event_time = localtime($eventtime);
	my $event_time = strftime "%b %d %Y %H:%M", localtime($eventtime);

	$parsedstring = "$event_time ($minutes" . "m) " . converttohtml($inp_title) . " $textstring";

	if (($debug) || ($specialdebug)) {
		writeDebug("parseSlotData $parsedstring");
	}

	return $parsedstring;
}

#-----------------------------------------------------------------
sub buildProgram {
	#
	# Year,Month,Day,Hour,Minute,Title,[Running Time,[Tuning]
	#------------------------------------------------------------

	# We really only need to minimally populate this.  Anything
	# After Title is optional

	my $year = int shift;
	my $month = int shift;
	my $day = int shift;
	my $hour = int shift;
	my $minute = int shift;
	my $titletext = shift;

	my $runningtime = int shift;
	my $tuning = int shift;

	my $specialdebug = 1;

	my $programdata = "";
	my $timestamp = "";
	my $genre1 = 0;
	my $genre2 = 0;
	my $genre3 = 0;
	my $genre4 = 0;

	$year = sprintf("%04d",$year);
	$month = sprintf("%02d",$month);
	$hour = sprintf("%02d",$hour);
	$minute = sprintf("%02d",$minute);
	$day = sprintf("%02d",$day);

	$timestamp .= $year;
	$timestamp .= $month;
	$timestamp .= $day;
	$timestamp .= $hour;
	$timestamp .= $minute;
	$timestamp .= $seconds;
	
	$eventtime = timegm(gmtime(as_epoch_seconds($timestamp)));

	my $titleLen = length($titletext)+1;

	$programdata .= converthex(272,$DWORD);			# struct_size
	$programdata .= converthex(1,$DWORD);			# autorecord
	$programdata .= converthex(1,$DWORD);			# isvalid
	$programdata .= converthex($tuning,$DWORD);		# tuning
	$programdata .= converthex(0,$DWORD);			# ProgramFlags
	$programdata .= converthex($eventtime,$DWORD);		# Eventtime
	$programdata .= converthex(0,$DWORD);			# TMSID
	$programdata .= converthex($runningtime,$WORD);		# minutes
	$programdata .= converthex(0,$BYTE);			# genre 1
	$programdata .= converthex(0,$BYTE);			# genre 2
	$programdata .= converthex(0,$BYTE);			# genre 3
	$programdata .= converthex(0,$BYTE);			# genre 4
	$programdata .= converthex(248,$WORD);			# rec len
	$programdata .= converthex($titleLen,$BYTE);		# title len
	$programdata .= converthex(1,$BYTE);			# episode length
	$programdata .= converthex(1,$BYTE);			# desc. length
	$programdata .= converthex(1,$BYTE);			# actor length
	$programdata .= converthex(1,$BYTE);			# guest length
	$programdata .= converthex(1,$BYTE);			# suzuki length
	$programdata .= converthex(1,$BYTE);			# prod. length
	$programdata .= converthex(1,$BYTE);			# dir. length
	$programdata .= converttext($titletext,228);		# description block

	if (($debug) || ($specialdebug)) {
		writeDebug("buildProgram $programdata");
	}
	
	return $programdata;

}	

#-----------------------------------------------------------------
sub buildSlotData {
	#
	# Builds SlotData Structure
	#
	# Parameters: Year,Month,Day,Hour,Minute,Length,Channel,
	#             Quality,Guaranteed,Recurring,DaysofWeek,
	#             Keep,IS GMT,Input Source,Tuning)
	#
	# Returns: SlotData HexString
	#
	#---------------------------------------------------------

	# Year,Month,Day,Hour,Minute,Length,Channel,Quality,Guaranteed,Recurring,DaysofWeek,Keep,IS GMT,Input Source[,Tuning])

	my $year = int shift;
	my $month = int shift;
	my $day = int shift;
	my $hour = int shift;
	my $minute = int shift;
	my $runningtime = int shift;
	my $channel = shift;
	my $quality = int shift;
	my $guaranteed = int shift;
	my $recurring = int shift;
	my $daysofweek = int shift;
	my $keep = int shift;
	my $isgmt = int shift;
	my $inputsource = int shift;			# Usually 3
	my $tuning = int shift;				# 0 is fine.
	my $slotdata = "";
	my $seconds = "00";

	my $specialdebug = 1;

	if ($guaranteed) {
		$guaranteed = "FFFFFFFF";
	}else{
		$guaranteed = "00000000";
	}

	if ($recurring) {
		$recurring = "FFFFFFFF";
	}else{
		$recurring = "00000000";
		$keep = 0;
	}

	if ($daysofweek == 0) {
		$daysofweek = 127;
	}

	$year = sprintf("%04d",$year);
	$month = sprintf("%02d",$month);
	$hour = sprintf("%02d",$hour);
	$minute = sprintf("%02d",$minute);
	$day = sprintf("%02d",$day);

	my $timestamp = "";

	$timestamp .= $year;
	$timestamp .= $month;
	$timestamp .= $day;
	$timestamp .= $hour;
	$timestamp .= $minute;
	$timestamp .= $seconds;


	if ($isgmt == 0) {
	
		$eventtime = timegm(gmtime(as_epoch_seconds($timestamp)));

		($seconds,$minute,$hour,$day,$month,$year,$wday,$yday) =
					    gmtime($eventtime);  
		$year += 1900;  
		$month++;

	}

	$slotdata .= converthex(3,$DWORD);		# unknown1 (required)
	$slotdata .= converthex($year,$WORD);		# year
	$slotdata .= converthex($month,$WORD); 		# month
	$slotdata .= converthex($day,$WORD); 		# day
	$slotdata .= converthex($hour,$WORD); 		# hour
	$slotdata .= converthex($minute,$WORD);     	# minute
	$slotdata .= converthex(0,$WORD);		# second (unused)
	$slotdata .= converthex(26924,$DWORD);		# 0x692C is manual rec.
	$slotdata .= converthex($runningtime,$DWORD);	# minutes
	$slotdata .= converthex($quality,$DWORD);	# quality level
	$slotdata .= converthex($inputsource,$DWORD);	# input source (0 ANT/Raw RF, 1 LINE 1,2 LINE 2, 3 is tuner)
	$slotdata .= converthex($tuning,$DWORD);	# channel index (doesn't matter on a slot reqeuest)
	$slotdata .= converthex(1,$DWORD);		# manual record (should be 0x01 for manual recordings)
	$slotdata .= $guaranteed;			# guaranteed 0xFFFFFFFF if true
	$slotdata .= $recurring;			# recurring 0xFFFFFFFF if true
	$slotdata .= converthex($keep,$DWORD);		# keep
	$slotdata .= converthex($daysofweek,$BYTE);	# days of week flag
	$slotdata .= converthex(0,$BYTE);		# after padding
	$slotdata .= converthex(0,$BYTE);		# before padding
	$slotdata .= converthex(0,$BYTE);		# flags (unused)
	$slotdata .= converthex(0,$DWORD);		# unused1 
	$slotdata .= converthex(0,$DWORD);		# category (index)	
	$slotdata .= converthex(0,$DWORD);		# unused2
	$slotdata .= converthex(0,$DWORD);		# firstrun (0x00 = all)
	$slotdata .= converthex(0,$DWORD);		# flags1
	$slotdata .= converttext($channel,20);		# channel label (eg. BBCA(Cable) )
	$slotdata .= converthex(0,$DWORD);		# flags2
	$slotdata .= converthex(0,$DWORD);		# flags3
	$slotdata .= converthex(0,$DWORD);		# flags4
	$slotdata .= converthex(0,$DWORD);		# flags5

	if (($debug) || ($specialdebug)) {
		writeDebug("buildSlotData $slotdata");
	}	
	return $slotdata;

}


#-----------------------------------------------------------------
sub buildRecordRequest {
	#
	# Builds RecordRequest Structure for get_slot_request
	#
	# Parameters: Year,Month,Day,Hour,Minute,Length,Channel,
	#             Quality,Guaranteed,Recurring,DaysofWeek,
	#             Keep,[First Run Only],[IS GMT],[Category],[post Pad],[PrePad])
	#
	# Returns: RecordRequest HexString
	#
	#---------------------------------------------------------

	# Year,Month,Day,Hour,Minute,Length,Channel(Tuning),Quality,Guaranteed,Recurring,DaysofWeek,Keep,[FirstRun],[IS GMT],[Category],[Post Pad],[Pre Pad])

	my $year = int shift;
	my $month = int shift;
	my $day = int shift;
	my $hour = int shift;
	my $minute = int shift;
	my $runningtime = int shift;
	my $channel = int shift;
	my $quality = int shift;
	my $guaranteed = int shift;
	my $recurring = int shift;
	my $daysofweek = int shift;
	my $keep = int shift;
	my $firstrun = int shift;
	my $isgmt = int shift;
	my $category = int shift;
	my $postpad = int shift;
	my $prepad = int shift;

	my $specialdebug = 1;

	my $recordrequest = "";
	my $seconds = "00";

	if ($guaranteed) {
		$guaranteed = "FFFFFFFF";
	}else{
		$guaranteed = "00000000";
	}

	if ($recurring) {
		$recurring = "FFFFFFFF";
	}else{
		$recurring = "00000000";
		$keep = 0;
	}

	if ($daysofweek == 0) {
		$daysofweek = 127;
	}

	$year = sprintf("%04d",$year);
	$month = sprintf("%02d",$month);
	$hour = sprintf("%02d",$hour);
	$minute = sprintf("%02d",$minute);
	$day = sprintf("%02d",$day);

	my $timestamp = "";

	$timestamp .= $year;
	$timestamp .= $month;
	$timestamp .= $day;
	$timestamp .= $hour;
	$timestamp .= $minute;
	$timestamp .= $seconds;

	if ($isgmt == 0) {
	
		$eventtime = timegm(gmtime(as_epoch_seconds($timestamp)));

		($seconds,$minute,$hour,$day,$month,$year,$wday,$yday) =
					    gmtime($eventtime);  
		$year += 1900;  
		$month++;
	}

	$recordrequest .= converthex(3,$DWORD);			# unknown1 (required)
	$recordrequest .= converthex($year,$WORD);		# year
	$recordrequest .= converthex($month,$WORD); 		# month
	$recordrequest .= converthex($day,$WORD); 		# day
	$recordrequest .= converthex($hour,$WORD); 		# hour
	$recordrequest .= converthex($minute,$WORD);     	# minute
	$recordrequest .= converthex(0,$WORD);			# second (unused)
	$recordrequest .= converthex(0,$DWORD);			# doesn't matter
	$recordrequest .= converthex($runningtime,$DWORD);	# minutes
	$recordrequest .= converthex($quality,$DWORD);		# quality level 
	$recordrequest .= converthex(3,$DWORD);			# input source (3 is tuner)
	$recordrequest .= converthex($channel,$DWORD);		# channel index (doesn't matter on a slot reqeuest)
	$recordrequest .= converthex(0,$DWORD);			# manual record (should be 0x01 for manual recordings)
	$recordrequest .= $guaranteed;				# guaranteed 0xFFFFFFFF if true
	$recordrequest .= $recurring;				# recurring 0xFFFFFFFF if true
	$recordrequest .= converthex($keep,$DWORD);		# keep
	$recordrequest .= converthex($daysofweek,$BYTE);	# days of week flag
	$recordrequest .= converthex($postpad,$BYTE);		# after padding
	$recordrequest .= converthex($prepad,$BYTE);		# before padding
	$recordrequest .= converthex(0,$BYTE);			# flags (unused)
	$recordrequest .= converthex(0,$DWORD);			# unused1 
	$recordrequest .= converthex($category,$DWORD);		# category (index)	
	$recordrequest .= converthex(0,$DWORD);			# unused2
	$recordrequest .= converthex($firstrun,$DWORD);		# firstrun (0x00 = all)
	
	if (($debug) || ($specialdebug)) {
		writeDebug("buildRecordRequest $recordrequest");
	}

	return $recordrequest;

}


#--------------------------------------------------------------------------------
# Read Binary Data Routines - it always looks in snapshotbody at guideptr
#--------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------
sub GetNextDWORD{
	my $retval = unpack("N",substr($snapshotbody,$guideptr,4));

	$guideptr = $guideptr + 4;

	return int $retval;
}

#----------------------------------------------------------------------------------------
sub GetNextWORD{
	my $retval = unpack("n",substr($snapshotbody,$guideptr,2));

	$guideptr = $guideptr + 2;

	return int $retval;
}

#----------------------------------------------------------------------------------------
sub GetNextBYTE{
	my $retval = unpack("C",substr($snapshotbody,$guideptr,1));

	$guideptr = $guideptr + 1;

	return $retval;
}

#----------------------------------------------------------------------------------------
sub GetSZ($){
	my $count = int shift;
	if ($count < 0) {
		return "";
	}
	my $retval = unpack("Z$count",substr($snapshotbody,$guideptr,$count));

	$guideptr = $guideptr + $count;

	return $retval;
}

#----------------------------------------------------------------------------------------
sub GetRaw($){
	my $count = int shift;
	if ($count < 0) {
		return "";
	}
	my $retval = unpack("a$count",substr($snapshotbody,$guideptr,$count));

	$guideptr = $guideptr + $count;

	return $retval;
}

1;
