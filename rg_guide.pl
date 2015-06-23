#!/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
# Theme Stuff based upon ReplaySchedule.pl by Kevin J. Moye
#  $Id: rg_guide.pl,v 1.5 2003/11/04 00:31:05 pvanbaren Exp $
#
# SCHEDULE RESOLVER MODULE: RG_GUIDE
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
#-----------------------------------------------------------------------------------
#
#  The Schedule interface must define the following functions.
#  All functions must be defined
#
#  getFreshScheduleTable ( $replayid )
#    - $replayid is the database identifier of the unit to check
#    - download a fresh set of schedule information from the replaytv
#    - must save the schedule information so a cached copy can be loaded later
#    - returns 0 if successful
#
#  getCachedScheduleTable ( $replayid )
#    - $replayid is the database identifier of the unit to check
#    - load in the previously cached copy of the schedule information
#    - returns 0 if successful
#
#  ProcessScheduleTable ( )
#    - called after all tables are loaded, but prior to displaying any details
#    - prepares the schedule information for use and initialize any related variables
#    - does not return any value
#
#  compareScheduleTable ( $Stmt )
#    - $Stmt is a database query statement that returns the list of shows
#      to be displayed
#    - process all schedule tables to prepare scheduling details
#      and priorities for the selected shows
#    - called after all tables are loaded, but prior to displaying any details
#    - does not return any value
#
#  getScheduleDetails ( $programid , $timing )
#    - $programid is the database identifier the program to check
#    - $timing is 0 for a past show, 1 for a present show, 2 for a future show
#    - returns an icon or text string to be inserted into the html code
#      indicating if the show is to scheduled to be recorded.
#    - returns a "" string if no information available
#    - may set the global $bgcolor variable to determing table background color
#
#  AboutScheduler
#    - Returns optional text which is placed in the program log file.
#
#  SchedulerDoBatchUpdate
#    - If some type of nightly processing is perferred or required this should
#      return true (1), otherwise return 0.
#
#  SchedulebarSupported
#    - If the module supports the ScheduleBar (within replayguide.pl) this should
#      return true (1), otherwise return 0.
#
#  ToDoSupported
#    - If the module supports the ToDo List (within replayguide.pl) this should
#      return true (1), otherwise return 0.
#    
#-----------------------------------------------------------------------------------

require HTTP::Request;
require HTTP::Headers;
require LWP::UserAgent;
use Time::Local;
use POSIX qw( strftime getcwd );

my $_version = "Personal ReplayGuide|Simple Scheduler Resolver Module|1|1|201|Lee Thompson,Philip Van Baren,Kanji T. Bates,Kevin J. Moye";

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

require 'rg_replay.pl';

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

#------------------------------------------------------------------------------------
# Set up locals
#------------------------------------------------------------------------------------

my $program_starttime = "";
my $program_title = "";
my $program_tuning = "";
my $program_minutes = 0;
my $program_quality = 2;
my $program_guaranteed = 1;
my $program_recurring = 1;
my $program_category = 0;
my $program_beforepad = 0;
my $program_afterpad = 0;
my $program_daysofweek = 127;
my $program_keep = 1;
my $program_replaytv = 0;
my $program_stop = "";
my $program_length = 0;
my $program_icon = "";
my $program_true_start = "";
my $display_time = "";
my $showlist = "";

#------------------------------------------------
sub getCachedScheduleTable {

	my $retcode = 0;
	my $replayid = shift;

	#-------------------------------------------------------------------
	# Read the snapshot files into memory
	#-------------------------------------------------------------------

	my $replayaddr = $rtvaddress{$replayid};
	my $replaylabel = $rtvlabel{$replayid};
	

	if (open(SNAPSHOT,"<$rtv_snapshotpath/$replayaddr.bin")) {
		binmode SNAPSHOT;
		($junk,$junk,$junk,$junk,$junk,$junk,$junk,$size,$junk,$junk,$junk,$junk,$junk) = stat("$rtv_snapshotpath/$replayaddr.bin");
		read SNAPSHOT,$snapshotbody,$size;
		close SNAPSHOT;
		if (length($snapshotbody) == $size) {
			$retcode = 0;
			writeDebug("Using cached GuideSnapshot for ReplayTV \#$replayid \"$replaylabel\" at $replayaddr");
		}else{
			writeDebug("Warning! Attempt to read '$rtv_snapshotpath/$replayaddr.bin' failed (wrong size)");
			$retcode = 1;	
		}
	}else{
		writeDebug("Warning! Attempt to open '$rtv_snapshotpath/$replayaddr.bin' failed (not present)");
		$retcode = 1;
	}
	return $retcode;
}

#------------------------------------------------
sub ProcessScheduleTable {
	# Process the schedule tables to create ReplayTV Events
	#---------------------------------------------------------------------------

	#-------------------------------------------------------------------
	# Collect ReplayTV Events
	#-------------------------------------------------------------------

	$eventcount = collectRTVChannels($replaylist,1);
	writeDebug("There are $eventcount ReplayTV Events");
}

#------------------------------------------------
sub getFreshScheduleTable {
	# Refresh the tables used to determine scheduled programs
	#---------------------------------------------------------------------------
	my $retcode = 0;
	my $replayid = shift;
	my $replayaddr = $rtvaddress{$replayid};
	my $replaylabel = $rtvlabel{$replayid};
	my $snapshottime = time;
	my $specialdebug = 0;

	$guideptr = 0;

	if ($specialdebug) {
		writeDebug("getFreshScheduleTable::starting($replayid)");
	}

	if (length($replayaddr) < 1) {
		writeDebug("getFreshScheduleTable::replayaddr is null");
		if ($specialdebug) {
			writeDebug("getFreshScheduleTable::Exiting(1)");
		}

		return 1;
	}

	if ($rtvport{$replayid} != 80) {
		$replaycmd = "http://$replayaddr:$rtvport{$replayid}/http_replay_guide-get_snapshot?guide_file_name=0";
	}else{
		$replaycmd = "http://$replayaddr/http_replay_guide-get_snapshot?guide_file_name=0";
	}

	$ua = LWP::UserAgent->new;
	$request = HTTP::Request->new(GET => $replaycmd);
	$response = $ua->request($request);

	if ($response->is_success) {
		writeDebug("Downloaded GuideSnapshot from ReplayTV \#$replayid \"$replaylabel\" at $replayaddr using $replaycmd");
		$guidesnapshot = $response->content;
	} else {
		#
		# If we can't contact the unit, try to just use the
		# cache.
		#

		writeDebug("Warning! Could Not Contact $replayaddr for a fresh snapshot");

		if (open(SNAPSHOT,"<$rtv_snapshotpath/$replayaddr.bin")) {
			binmode SNAPSHOT;
			($junk,$junk,$junk,$junk,$junk,$junk,$junk,$size,$junk,$junk,$junk,$junk,$junk) = stat("$rtv_snapshotpath/$replayaddr.bin");
			read SNAPSHOT,$snapshotbody,$size;
			close SNAPSHOT;
			if (length($snapshotbody) == $size) {
				writeDebug("getFreshScheduleTable::Warning! Using cached information for ReplayTV \#$replayid \"$replaylabel\" at $replayaddr");
				if ($specialdebug) {
					writeDebug("getFreshScheduleTable::Exiting(0)");
				}

				return 0;						
			}else{
				writeDebug("getFreshScheduleTable::Attempt to read cached '$rtv_snapshotpath/$replayaddr.bin' failed (wrong size)");
				if ($specialdebug) {
					writeDebug("getFreshScheduleTable::Exiting(1)");
				}

				return 1;
			}
		}else{
			writeDebug("getFreshScheduleTable::Attempt to open cached '$rtv_snapshotpath/$replayaddr.bin' failed (not present)");
			if ($specialdebug) {
				writeDebug("getFreshScheduleTable::Exiting(1)");
			}

			return 1;
		}
	}
		
	#--------------------------------------------------------------
	# Strip off extra bits
	#--------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("getFreshScheduleTable::Trimming Data");
	}


	$snapshotbody = "";
	($guidetag,$junk,$snapshotbody,$junk2) = split(/#####/, $guidesnapshot, 9);

	#--------------------------------------------------------------
	# Update Database
	#--------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("getFreshScheduleTable::Parsing Header");
	}

	&ParseRTVHeader;

	if ($specialdebug) {
		writeDebug("getFreshScheduleTable::SV: $guideheader{snapshotversion} OS: $guideheader{osversion} CC: $guideheader{channelcount}");
		writeDebug("getFreshScheduleTable::$category");
	}

	my $replayosversion = $guideheader{snapshotversion} * 10 + 30 + $guideheader{osversion};
	my $guideversion = $guideheader{snapshotversion};
	my $categories = $category;

	$Stmt = "UPDATE $db_table_replayunits SET categories = '$categories', " .
		"replayosversion = '$replayosversion', " .
		"guideversion='$guideversion'" .
		"WHERE replayid = '$replayid';";

	# $Stmt = "UPDATE $db_table_replayunits SET lastsnapshot = $snapshottime WHERE replayid = '$replayid';";
	#--------------------------------------------------------------
	# Dump Snapshot to Disk
	#--------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("getFreshScheduleTable::Dumping to Disk");
	}


	if (open(SNAPSHOT,">$rtv_snapshotpath/$replayaddr.bin")) {
		binmode SNAPSHOT;
		print SNAPSHOT $snapshotbody;
		close SNAPSHOT;

		my $db_handle = &StartDSN;

		if (sqlStmt($db_handle,$Stmt)) {
			writeDebug("getFreshScheduleTable::Refresh for ReplayTV \#$replayid \"$replaylabel\" at $replayaddr successful, cache saved successfully, database update successful");
		}else{
			writeDebug("getFreshScheduleTable::Refresh for ReplayTV \#$replayid \"$replaylabel\" at $replayaddr successful, cache saved successfully, database update failed");
		}

		endDSN("",$db_handle);
		undef $db_handle;
	}else{
		writeDebug("getFreshScheduleTable::Warning! Attempt to write '$rtv_snapshotpath/$replayaddr.bin' failed");
	}

	if ($specialdebug) {
		writeDebug("getFreshScheduleTable::Exiting(0)");
	}

	return 0;
}


#------------------------------------------------
sub compareScheduleTable {
	# Compare the scheduled events with the displayed events
	# This assumes $Stmt is defined such that it returns the displayed events
	#---------------------------------------------------------------------------

	my $Stmt = shift;

	writeDebug("Building show list for $sql_start through $sql_end");
	writeDebug("Building show list containing channels $inp_firsttune - $inp_lasttune");
	writeDebug("SQL: $Stmt");

	my $db_handle = &StartDSN;
	my $sth = sqlStmt($db_handle,$Stmt);

	if ($sth) {

		while ( $row = $sth->fetchrow_hashref ) {
			$program_id = $row->{'programid'};
			$program_start = sqltotimestring($row->{'starttime'});
			$program_true_start = $program_start;
			$program_stop = sqltotimestring($row->{'endtime'});
			$program_true_stop = $program_stop;
			$program_title = $row->{'title'};
			$program_subtitle = $row->{'subtitle'};
			$program_desc = $row->{'description'};
			$program_tuning = $row->{'tuning'};
			$program_channel = $row->{'channel'};
		
			$program_category = $row->{'category'};
			$program_mpaarating = $row->{'mpaarating'};
			$program_vchiprating = $row->{'vchiprating'};
			$program_episodenum = $row->{'episodenum'};
			$program_movieyear = int $row->{'movieyear'};
			$program_stereo = int $row->{'stereo'};
			$program_repeat = int $row->{'repeat'};
			$program_starrating = $row->{'starrating'};
			$program_captions = $row->{'captions'};

			if (as_epoch_seconds($program_stop) < as_epoch_seconds($program_start)) {
				$program_stop = as_time_string($rng_end);
				$fudged_length = 1;
			}

			#-------------------------------------------------------------------
			# Prepare Variables and Calculate Running Time
			#-------------------------------------------------------------------

			$program_length = getMinutes($program_start,$program_stop);
			$display_length = $program_length;


			if ($program_id eq $prev_id) {
				next;
			}

			$tempvar = isScheduled($program_true_start,$program_channel,$program_title,$program_repeat);

			if (length($tempvar) > 0) {
				if (length($showlist) > 0) {
					$showlist .= "|";
				}
				$showlist .= $tempvar;
			}

			

			$prev_id = $program_id;

		}
	}

	endDSN("",$db_handle);
	undef $db_handle;

	return 1;
}


#------------------------------------------------
sub getScheduleDetails {
	#
	# Check if a show is scheduled, and if so, return an icon
	#---------------------------------------------------------------------------
	my $inp_programid = shift;
	my $inp_timing = shift;
	my $retval = "";
	my $theme_icon = "";
	my $specialdebug = 0;
	my $Stmt = "";


	if ($specialdebug) {
		writeDebug("getScheduleDetails::starting($inp_programid,$inp_timing)");
	}

	my $db_handle = &StartDSN;
	$Stmt = "SELECT * FROM $db_table_tvlistings WHERE programid = '$inp_programid';";

	my $sth = sqlStmt($db_handle,$Stmt);

	if ($specialdebug) {
		writeDebug("getScheduleDetails::DSN: $db_handle STH: $sth ($Stmt)");
	}


	if ( $sth ) {
		$row = $sth->fetchrow_hashref;	

		$program_starttime = sqltotimestring($row->{'starttime'});
		$program_true_start = $program_starttime;
		$program_stop = sqltotimestring($row->{'endtime'});
		$program_tuning = int $row->{'tuning'};
		$program_title = $row->{'title'};
		$program_subtitle = $row->{'subtitle'};
		$program_desc = $row->{'description'};
		$program_category = $row->{'category'};
		$program_advisories = $row->{'advisories'};
		$program_mpaarating = $row->{'mpaarating'};
		$program_vchiprating = $row->{'vchiprating'};
		$program_episodenum = $row->{'episodenum'};
		$program_movieyear = int $row->{'movieyear'};
		$program_stereo = int $row->{'stereo'};
		$program_repeat = int $row->{'repeat'};
		$program_starrating = $row->{'starrating'};
		$program_captions = $row->{'captions'};
		$program_channel = $row->{'channel'};

		($program_stars,$junk) = split(/\//,$program_starrating);

		$fudged_length = 0;

		if (as_epoch_seconds($program_stop) < as_epoch_seconds($program_starttime)) {
			$program_stop = as_time_string($rng_end);
			$fudged_length = 1;
		}

		$program_length = getMinutes($program_starttime,$program_stop);

	}else{
		writeDebug("getScheduleDetails::Lookup Failed: $Stmt / Error: " . &GetLastSQLError());
	}

	endDSN($sth,$db_handle);


	if ($rtvaccess > 0) {
		if ($specialdebug) {
			writeDebug("getScheduleDetails::rtvaccess enabled, getting schedule icons");
			writeDebug("getScheduleDetails::$program_true_start,$program_channel,$program_title,$program_repeat");
		}

		$isScheduled = isScheduled($program_true_start,$program_channel,$program_title,$program_repeat);
		if ($specialdebug) {
			writeDebug("getScheduleDetails::isScheduled: $isScheduled");
			writeDebug(as_hhmm(as_epoch_seconds($program_true_start)));
		}
		if (length($isScheduled) > 0) {
			$retval .= buildIcon($isScheduled);
			if ($showrtvthemes) {
				if (length($showlist) < 1) {
					$theme_icon = getThemeIcon($isScheduled);
				}else{
					$theme_icon = getThemeIcon($showlist);
				}
			}
			$retval .= $theme_icon;
		}
	}else{
		if ($specialdebug) {
			writeDebug("getScheduleDetails::rtvaccess disabled");
		}

		$isScheduled = 0;
	}

	#-------------------------------------------------------------------
	# Color Code the Column
	#-------------------------------------------------------------------

	if (length($theme_icon)) {
		$bgcolor = $color_theme[ $inp_timing ];
	} elsif(length($retval)) {
		$bgcolor = $color_scheduled[ $inp_timing ];
	}

	if ($specialdebug) {
		writeDebug("getScheduleDetails::exiting($retval)");
	}

	return $retval;
}

#---------------------------------------------------------------------------------------
sub getThemeIcon {
	#
	# Return the Icon for the Theme Recording
	#
	# Parameter: rtvevent structure, separate multiples with a |
	#
	# ------------------------------------------------------------------------------

	my $rtvdata = shift;
	my $specialdebug = 0;					# Enable Debug Logging
	my $programtitle = $program_title;
	my $retaddr = "";
	my $themetext = "";
	my $theme_icon_alt = "";
	my $themeicon = "";

	my $ctr = 0;
	my $overlap_flag = 0;

	my $curr_rtv = "";
	my $curr_show = "";

	my $slotstart = as_epoch_seconds($program_true_start);
	my $slotstop = as_epoch_seconds($program_stop) - 1;
	my $showstart = 0;
	my $showstop = 0;

	my $laststart = 0;
	my $laststop = 0;
	my $lasttuning = 0;
	my $lastcreate = 0;
	my $lastguaranteed = 0;
	my $lasttype = 0;

	if ($specialdebug) {
		writeDebug("getThemeIcon::starting($rtvdata)");
		writeDebug("getThemeIcon::" . as_hhmm(as_epoch_seconds($program_true_start)) . " for $program_tuning ($program_channel) \"$programtitle\"");
	}

	if (length($rtvdata) < 1) {
		#----------------------------------------------
		# No scheduled data, nothing to do!
		#----------------------------------------------
		if ($specialdebug) {
			writeDebug("getThemeIcon::nothing to do");
			writeDebug("getThemeIcon::(exiting)");
		}
		return $retval;
	}else{
		if ($specialdebug) {
			writeDebug("getThemeIcon::$rtvdata");
		}
	}

	if (length(isTheme($program_title)) < 1) {
		#----------------------------------------------
		# Not a theme, might as well just quit now!
		#----------------------------------------------
		if ($specialdebug) {
			writeDebug("getThemeIcon::$program_title is not a theme");
			writeDebug("getThemeIcon::(exiting)");
		}
		return $retval;
	}

	

	#------------------------------------------------------
	# Initialize
	#------------------------------------------------------

	for ( split /,/, $replaylist ) {
		/,/;
		$curr_rtv = $rtvaddress{$_};
		$ctr = 0;

		do {	
			$ctr++;
			$curr_show = $scheduledshows{$curr_rtv}[$ctr];
			$scheduledshows{$curr_rtv}[$ctr] = "";
		} while (length($curr_show) > 0);

		$retval{$curr_rtv} = "";
	}

	#-----------------------------------------------------
	# For each Replay build a list of shows that overlap
	# with the slot.
	#
	# (Basically this sorts by address)
 	#-----------------------------------------------------

	for ( split /,/, $replaylist ) {
		/,/;
			
		$curr_rtv = $rtvaddress{$_};
		$ctr = 0;

		for ( split /\|/, $rtvdata ) {
			/\|/;

			(my $replayid,my $rtveventtime,my $guaranteed,my $channeltype,my $daysofweek,my $channelflags,my $beforepadding,my $afterpadding,my $showlabel,my $channelname,my $themeflags,my $themestring,my $thememinutes,my $rtvcreate,my $scheduledtime,my $programtuning,my $displaylength,my $programtruestart) = split(/;/,$_);
			$eventtime = timegm(gmtime($rtveventtime));

			$showstart = $scheduledtime;
			$showstop = $scheduledtime + ($displaylength * 60) -1;

			if ($curr_rtv eq $rtvaddress{$replayid}) {
				$overlap_flag = 0;
				$overlap_flag = &doTimesOverlap($slotstart,$slotstop,$showstart,$showstop);

				if ($specialdebug) {
					writeDebug("getThemeIcon::$replayid,OF:$overlap_flag,SLOTS:$slotstart,SLOTE:$slotstop,SHOWS:$showstart,SHOWE:$showstop;EVENT:$eventtime;CT:$channeltype;SL:$showlabel");
				}

				if ($overlap_flag) {
					$ctr++;
					$scheduledshows{$rtvaddress{$replayid}}[$ctr] = $_;
					if ($specialdebug) {
						writeDebug("getThemeIcon::found a candidate for $rtvaddress{$replayid} (#$ctr)");
					}
				}
			}
		}
	}


	#----------------------------------------------------
	# Now that we have the list of potentials we need
	# to do conflict resolution (if there's more than one
	# qualifying show) for each Replay.
	#----------------------------------------------------

	if ($specialdebug) {
		writeDebug("getThemeIcon::resolving conflicts");
	}

	for ( split /,/, $replaylist ) {
		/,/;
			
		$curr_rtv = $rtvaddress{$_};
		$ctr = 0;

		if ($specialdebug) {
			writeDebug("getThemeIcon::resolving conflicts for $curr_rtv");
		}

		do {	
			$ctr++;
			$curr_show = $scheduledshows{$curr_rtv}[$ctr];

			if ($specialdebug) {
				writeDebug("getThemeIcon::$curr_rtv: $ctr \"$curr_show\"");
			}

			if (length($curr_show) > 0) {
				(my $replayid,my $rtveventtime,my $guaranteed,my $channeltype,my $daysofweek,my $channelflags,my $beforepadding,my $afterpadding,my $showlabel,my $channelname,my $themeflags,my $themestring,my $thememinutes,my $rtvcreate,my $scheduledtime,my $programtuning,my $displaylength,my $programtruestart) = split(/;/,$curr_show);
				$eventtime = timegm(gmtime($rtveventtime));

				if (length($showlabel) > 0) {
					$showlabel = normalizertvname($showlabel);
				}

				if (length($themestring) > 0) {
					$themestring = normalizertvname($themestring);
				}

				if ($specialdebug) {
					writeDebug("getThemeIcon::$curr_rtv: $channeltype $showlabel ");
				}


				$showstart = $scheduledtime;
				$showstop = $scheduledtime + ($displaylength * 60) -1;

				$overlap_flag = 0;
				$overlap_flag = doTimesOverlap($showstart,$showstop,$laststart,$laststop);
	
				if ($overlap_flag > 0) {
					if ($specialdebug) {
						writeDebug("getThemeIcon::$curr_rtv: $channeltype $showlabel: Overlap Detected.  Using Mode: $rtv_version{$replayid} for Conflict Checks for $showlabel ($themestring) type: $channeltype");
					}

					if ($rtv_version{$replayid} == 2) {
						#--------------------------------------------------------
						# 5.x Conflict Resolution
						#--------------------------------------------------------
						if ($rtvcreate > $lastcreate) {
							$retval{$curr_rtv} = $image_tw;
						}else{
							$retval{$curr_rtv} = $image_tl;
						}
					}else{
						#--------------------------------------------------------
						# 4.x Conflict Resolution				
						#--------------------------------------------------------
						if ($programtuning > $lasttuning) {
							$retval{$curr_rtv} = $image_tw;
						}else{
							$retval{$curr_rtv} = $image_tl;
						}
					}					


					#---------------------------------------------------------------
					# If the previous one is guaranteed and this one isn't, this one
					# will lose.
					#---------------------------------------------------------------

					if ($specialdebug) {
						writeDebug("getThemeIcon::$curr_rtv: $channeltype $showlabel: checking guaranteed levels $guaranteed vs $lastguaranteed");
					}

	
					if ($guaranteed > $lastguaranteed) {
						$retval{$curr_rtv} = $image_tw;
					}else{
						$retval{$curr_rtv} = $image_tl;
					}


					#---------------------------------------------------------------
					# If it's up against a replaychannel (recurring or single) it
					# loses immediately.
					#
					# NOTE: This may no longer be true for 5.0
					#
					#---------------------------------------------------------------

					if ($specialdebug) {
						writeDebug("getThemeIcon::$curr_rtv: $channeltype $showlabel: checking to see if current overlap is not a theme ($channeltype)");
					}

					if (($channeltype == 1) || ($channeltype == 3 )) {
						$retval{$curr_rtv} = $image_tl;
						if (($programtuning == $lasttuning) && ($lasttype == 2)){
							#-------------------------------------------------------
							# If it matches as both a replaychannel AND a theme, 
							# just hide the theme.  
							#
							# If you'd rather see both comment the following line
							# out.
							#
							#-------------------------------------------------------
							$retval{$curr_rtv} = "";
						}
						next;
					}


					#---------------------------------------------------------------
					# If the theme just won't fit, it goes away.
					#---------------------------------------------------------------

					if ($speicaldebug) {
						writeDebug("getThemeIcon::$curr_rtv: $channeltype $showlabel: checking to see if $display_length fits in $thememinutes");
					}

					if ($thememinutes < $display_length) {
						$retval{$curr_rtv} = $image_tl;
					}

					$lasttuning = $programtuning;
					$lastcreate = $rtvcreate;
					$lastguaranteed = $guaranteed;
					$lasttype = $channeltype;
				}else{
					if ($channeltype == 2) {
						if ($specialdebug) {
							writeDebug("getThemeIcon::$curr_rtv: $channeltype $showlabel: won due to no overlap");
						}
	
						$retval{$curr_rtv} = $image_tw;
	
						$lasttuning = $programtuning;
						$lastcreate = $rtvcreate;
						$lastguaranteed = $guaranteed;
						$lasttype = $channeltype;
					}else{
						if ($specialdebug) {
							writeDebug("getThemeIcon::$curr_rtv: $channeltype $showlabel: no winner this round (not a theme)");
						}
					}
				}

				$laststart = $showstart;
				$laststop = $showstop;
			}

			#-------------------------------------------------------
			# If the only entry for this Replay's slot is a theme
			# it wins automatically if the show fits in the theme.
			#-------------------------------------------------------


			if (($ctr == 2) && (length($scheduledshows{$curr_rtv}[$ctr]) < 1)) {
				(my $replayid,my $rtveventtime,my $guaranteed,my $channeltype,my $daysofweek,my $channelflags,my $beforepadding,my $afterpadding,my $showlabel,my $channelname,my $themeflags,my $themestring,my $thememinutes,my $rtvcreate,my $scheduledtime,my $programtuning,my $displaylength,my $programtruestart) = split(/;/,$scheduledshows{$curr_rtv}[1]);
				if ($channeltype == 2) {
					if ($specialdebug) {
						writeDebug("getThemeIcon::$themestring is winning by default");
					}

					if ($specialdebug) {
						writeDebug("getThemeIcon::checking to see if $display_length fits in $thememinutes");
					}

					if ($thememinutes < $display_length) {
						$retval{$curr_rtv} = $image_tl;
					}else{
						$retval{$curr_rtv} = $image_tw;	
					}
				}
			}		

		} while (length($curr_show) > 0);

	}						

	#----------------------------------------------------
	# By this point we should have a winner for each 
	# Replay in the list.
	#
	# $retval{address} contains the winning or losing
	# image name ($image_tw or $image_tl) - or null.
	#----------------------------------------------------


	#----------------------------------------------------
	# Build the icon for each Replay
	#----------------------------------------------------

	for ( split /,/, $replaylist ) {
		/,/;

		if (length($retval{$rtvaddress{$_}}) > 0 ) {
			if (length($themeicon) > 0) {
				$themeicon .= " / ";
			}

			if ($retval{$rtvaddress{$_}} eq $image_tl) {
				$themetext = "Theme in Conflict";
			}
			if ($retval{$rtvaddress{$_}} eq $image_tw) {
				$themetext = "Theme";
			}


			$theme_icon_alt = $rtvlabel{$_} . " - " . $themetext;

			if ($showrtvicons) {
				if (length($retval{$rtvaddress{$_}})) {
					if (substr($retval{$rtvaddress{$_}},0,7) eq "http://" ) {
						$themeicon .= "<img src=$retval{$rtvaddress{$_}} ALT=\"$theme_icon_alt\">";
					}else{
						$themeicon .= "<img src=$imagedir/$retval{$rtvaddress{$_}} ALT=\"$theme_icon_alt\">";
					}
					if ($showrtvtext) {
						$themeicon .= "($theme_icon_alt)";
					}
				}
			}else{
				if ($retval{$rtvaddress{$_}} eq $image_tl) {
					$themetext = "Theme in Conflict";
				}
				if ($retval{$rtvaddress{$_}} eq $image_tw) {
					$themetext = "Theme";
				}

				if ($showrtvtext) {
					$themeicon .= "$theme_icon_alt: $themetext";
				}
			}

		}
	}

	#----------------------------------------------------
	# Exit
	#----------------------------------------------------

	if ($specialdebug) {
		writeDebug("getThemeIcon::themeicon: $themeicon");
		writeDebug("getThemeIcon::(exiting)");
	}


	return $themeicon;
}


#---------------------------------------------------------------------------------------
sub buildIcon {
	#
	# Build a RTV Status Icon
	#
	# Parameter: one or more rtvevent structs separated by a |
	#
	# ------------------------------------------------------------------------------

	my $rtvdata = shift;
	my $retval = "";
	my $program_icon = "";
	my $program_icon_alt = "";
	my $program_text = "";

	if (length($rtvdata) < 1) {
		return $retval;
	}

	for ( split /\|/, $rtvdata ) {
		/\|/;
		(my $replayid,my $rtveventtime,my $guaranteed,my $channeltype,my $daysofweek,my $channelflags,my $beforepadding,my $afterpadding,my $showlabel,my $channelname,my $themeflags,my $themestring,my $thememinutes,my $rtvcreate,my $scheduledtime,my $programtuning,my $displaylength,my $programtruestart) = split(/;/,$_);

		my $recurring = 0;
		my $theme = 0;
		my $single = 0;
			
		if ($channeltype == 1) {
			$recurring = 1;
		}

		if ($channeltype == 2) {
			$theme = 1;
		}

		if ($channeltype == 3) {
			$single = 1;
		}


		if ($recurring) {
			if ($guaranteed) {
				$program_icon = $image_gr;
				$program_text = "Guaranteed, Recurring";

				if ($afterpadding > 0)  {
					$program_icon = $image_apgr;
					$program_text = "Guaranteed, Recurring, Post-Padded";
				}
				if ($beforepadding > 0)  {
					$program_icon = $image_bpgr;
					$program_text = "Guaranteed, Recurring, Pre-Padded";

				}
				if (($afterpadding > 0) && ($beforepadding > 0))  {
					$program_icon = $image_ppgr;
					$program_text = "Guaranteed, Recurring, Padded";
				}
			}else{
				$program_icon = $image_r;
				$program_text = "Recurring";

				if ($afterpadding)  {
					$program_icon = $image_apr;
					$program_text = "Recurring, Post-Padded";
				}
				if ($beforepadding)  {
					$program_icon = $image_bpr;
					$program_text = "Recurring, Pre-Padded";
				}
				if (($afterpadding) && ($beforepadding))  {
					$program_icon = $image_ppr;
					$program_text = "Recurring, Padded";
				}
			}
		}

		if ($single) {
			if ($guaranteed) {
				$program_icon = $image_gs;
				$program_text = "Guaranteed, Single";

				if ($afterpadding)  {
					$program_icon = $image_apgs;
					$program_text = "Guaranteed, Single, Post-Padded";
				}
				if ($beforepadding)  {
					$program_icon = $image_bpgs;
					$program_text = "Guaranteed, Single, Pre-Padded";
				}
				if (($afterpadding) && ($beforepadding))  {
					$program_icon = $image_ppgs;
					$program_text = "Guaranteed, Single, Padded";
				}
			}else{
				$program_icon = $image_s;
				$program_text = "Single";
				if ($afterpadding)  {
					$program_icon = $image_aps;
					$program_text = "Single, Post-Padded";
				}
				if ($beforepadding)  {
					$program_icon = $image_bps;
					$program_text = "Single, Pre-Padded";
				}
				if (($afterpadding) && ($beforepadding))  {
					$program_icon = $image_pps;
					$program_text = "Single, Padded";
				}
			}
		}

		if ($theme) {
			#------------------------------------------------------------
			# Themes are handled separately
			#------------------------------------------------------------
			next;
		}

		$program_icon_alt = $rtvlabel{$replayid} . " - " . $program_text;

		if (length($retval) > 0) {
			$retval .= "/";
		}

		if ($showrtvicons) {
			if (length($program_icon) > 0) {
				if (substr($program_icon,0,7) eq "http://" ) {
					$retval .= "<img src=$program_icon ALT=\"$program_icon_alt\">";
				}else{
					$retval .= "<img src=$imagedir/$program_icon ALT=\"$program_icon_alt\">";
				}
			}
			if ($showrtvtext) {
				$retval .= "($program_icon_alt)";
			}
		}else{
			if ($showrtvtext) {
				$retval .= "$program_icon_alt: $program_text";
			}
		}
	}

	return $retval;
}

#---------------------------------------------------------------------------------------
sub isTheme {
	#
	# Determine if A Program is A Theme
	#
	# Parameter: text to match
	#
	# Returns array
	#
	# ------------------------------------------------------------------------------

	my $searchfor = shift;
	my $retval = "";
	my $specialdebug = 0;					# Enable Debug Logging
	my $ctr = 1;

	if (length($searchfor) > 0) {
		#----------------------------------------------------
		# If program title is passed in, make sure it doesn't
		# contain HTML coding or non alphas that the Replay
		# does not use.
		#----------------------------------------------------

		$searchfor = convertfromhtml($searchfor);
		$searchfor = normalizertvname($searchfor);
	}else{
		#----------------------------------------------------
		# Otherwise, bail
		#----------------------------------------------------
		if ($specialdebug) {
			writeDebug("isTheme::null parameter, returning");
		}
		return $retval;
	}

	if ($specialdebug) {
		writeDebug("isTheme::Looking for '$searchfor'");
		writeDebug("isTheme::$eventcount events to search");
	}
	
	do {
		$match = 0;

		(my $replayid,my $rtveventtime,my $guaranteed,my $channeltype,my $daysofweek,my $channelflags,my $beforepadding,my $afterpadding,my $showlabel,my $channelname,my $themeflags,my $themestring,my $thememinutes,my $rtvcreate) = split(/;/,$rtvevent[$ctr]);

		if ($specialdebug) {
			writeDebug("isTheme::event $ctr:$replayid,$rtveventtime,$guaranteed,$channeltype,$daysofweek,$channelflags,$beforepadding,$afterpadding,$showlabel,$channelname,$themeflags,$themestring,$thememinutes,$rtvcreate");
		}

		if (length($showlabel) > 0) {
			$showlabel = normalizertvname($showlabel);
		}

		if (length($themestring) > 0) {
			$themestring = normalizertvname($themestring);
		}

		if ($channeltype == 2) {
			if ($specialdebug) {
				writeDebug("isTheme::$searchfor==$themestring");
			}

			if ($themeflags & 4) {
				if ($searchfor eq $themestring) {
					$match = 1;
				}	
			}
			if ($themeflags & 8) {
				if ($searchfor =~ $themestring) {
					$match = 1;
				}	
			}
			if ($themeflags & 16) {
				# Search Desc/Subtitle
			}

			if ($match) {
				if ($specialdebug) {
					writeDebug("isTheme::match found (type $themeflags)");
				}

				if (length($retval) > 0) {
					$retval .= "|";
				}
				$retval .= $replayid;
			}

		}
		$ctr++;
	} while ($ctr <= $eventcount);

	if ($specialdebug) {
		writeDebug("isTheme::exiting($retval)");
	}
	return $retval;

}
#---------------------------------------------------------------------------------------
sub isScheduled {
	#
	# Determine if A Program is Scheduled by one or more RTVs
	#
	# Parameters: scheduled time, channel ID (call letters), title, repeat flag
	#
	# ------------------------------------------------------------------------------

	my $scheduledtime = as_epoch_seconds(shift);
	my $channelid = shift;
	my $programtitle = shift;				# Optional
	my $isrepeat = int shift;				# Optional
	my $retval = "";
	
	my $specialdebug = 0;					# Enable Debug Logging
	my $ctr = 1;
	my $match = 0;	

	my $replayid = "";
	my $eventtime = "";
	my $guaranteed = "";
	my $channeltype = "";
	my $daysofweek = "";
	my $channelflags = "";
	my $beforepadding = "";
	my $afterpadding = "";
	my $showlabel = "";
	my $channelname = "";
	my $rtveventtime = 0;

	if (length($programtitle) > 0) {

		# If program title is passed in, make sure it doesn't
		# contain HTML coding or non alphas that the Replay
		# does not use.

		$programtitle = convertfromhtml($programtitle);
		$programtitle = normalizertvname($programtitle);
	}

	if ($specialdebug) {
		writeDebug("isScheduled::Looking at " . &as_hhmm($scheduledtime) . " on $channelid for '$programtitle' repeat=$isrepeat");
		writeDebug("isScheduled::$eventcount events to search");
	}

	do {
		$match = 0;
		($replayid,$rtveventtime,$guaranteed,$channeltype,$daysofweek,$channelflags,$beforepadding,$afterpadding,$showlabel,$channelname,$themeflags,$themestring,$thememinutes,$rtvcreate) = split(/;/,$rtvevent[$ctr]);
		$eventtime = timegm(gmtime($rtveventtime));

		if ($specialdebug) {
			writeDebug("isScheduled::event $ctr:$replayid,$rtveventtime,$guaranteed,$channeltype,$daysofweek,$channelflags,$beforepadding,$afterpadding,$showlabel,$channelname,$themeflags,$themestring,$thememinutes,$rtvcreate");
		}


		if (length($showlabel) > 0) {
			$showlabel = normalizertvname($showlabel);
		}
		if (length($themestring) > 0) {
			$themestring = normalizertvname($themestring);
		}

		if ($specialdebug) {
			writeDebug("isScheduled::$channelname==$channelid");
		}

		if ($channelname eq $channelid) {
			if ($specialdebug) {
				writeDebug("isScheduled::Match Found ($channelid) Type: $channeltype");
			}


			if ($channeltype == 3) {
				if ($eventtime == $scheduledtime) {
					if (length($retval) > 0) {
						$retval .= "|";
					}
					$retval = $rtvevent[$ctr];
					$retval .= ";$scheduledtime;$program_tuning;$display_length;" . as_epoch_seconds($program_true_start);
				}
			}
			
			if ($channeltype == 1) {
				(my $rtvsec,my $rtvmin,my $rtvhour,my $rtvmday,my $rtvmon,my $rtvyear,my $rtvwday,my $rtvyday,my $rtvisdst) =
                                	                localtime($eventtime);

				(my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) =
        	                                        localtime($scheduledtime);
				
				if (($rtvhour == $hour) && ($rtvmin == $min)) {
	
					if ($specialdebug) {
						writeDebug("isScheduled::$programtitle==$showlabel");
					}

					if ($programtitle eq $showlabel) {
						$match = 1;
						if ($specialdebug) {
							writeDebug("isScheduled::Match Found ($showlabel)");
							writeDebug("isScheduled::Day of Week: $daysofweek (" . 2**$wday . ")");
							writeDebug("isScheduled::Repeat: $isrepeat, Channel Flags: $channelflags");
						}

						if ($daysofweek & (2**$wday)) {
								$match = 1;
						}else{
								$match = 0;
						}

						if (($isrepeat) && ($channelflags & 32)) {
								$match = 0;
						}
						if ($match) {
							if (length($retval) > 0) {
								$retval .= "|";
							}
							$retval .= $rtvevent[$ctr];
							$retval .= ";$scheduledtime;$program_tuning;$display_length;" . as_epoch_seconds($program_true_start);

						}
					}
				}	
			}

		}
		if ($channeltype == 2) {
			if ($themeflags & 4) {
				if ($programtitle eq $themestring) {
					if ($specialdebug) {
						writeDebug("isScheduled::Theme Match ($themestring) type 4");
					}

					$match = 1;
				}	
			}
			if ($themeflags & 8) {
				if ($programtitle =~ $themestring) {
					if ($specialdebug) {
						writeDebug("isScheduled::Theme Match ($themestring) type 8");
					}
					$match = 1;
				}	
			}
			if ($themeflags & 16) {
				# Search Desc/Subtitle
			}

			if ($match) {
				if (length($retval) > 0) {
					$retval .= "|";
				}
				$retval .= $rtvevent[$ctr];
				$retval .= ";$scheduledtime;$program_tuning;$display_length;" . as_epoch_seconds($program_true_start);

			}

		}
		$ctr++;
	} while ($ctr <= $eventcount);


	if ($specialdebug) {
		writeDebug("isScheduled::exiting($retval)");
	}

	return $retval;
}


#------------------------------------------------
sub AboutScheduler{
	# About Schedule Module
	#---------------------------------------------------------------------------

	my $about = "";
	$about .= "rg_guide by Lee Thompson, Kevin J. Moye and Philip Van Baren. ";
	$about .= "Simple, slow and buggy ;)";

	return $about;
}


#------------------------------------------------
sub SchedulerDefaultRefresh{
	#
	# Refresh options for the scheduler module.
	#
	# Time in minutes between guide refreshes 
	# (0 is batch only if do_batch_update is enabled, otherwise completely
        # disabled.)
	#---------------------------------------------------------------------------
	
	my $retcode = 15;
	
	if ($defaultrefreshinterval != -1) {
		$retcode = $defaultrefreshinterval;
	}
	
	return $retcode;
}

#------------------------------------------------
sub SchedulerDoBatchUpdate{
	# Refresh options for the scheduler module.
	#
	# Should scheduler module be updated at SQL time?
	#---------------------------------------------------------------------------
		
	return 0;
}


#------------------------------------------------
sub SchedulebarSupported{
	# Does this processor support the schedulebar?
	#---------------------------------------------------------------------------

	return 0;
}

#------------------------------------------------
sub ToDoSupported{
	# Does this processor support the todolist?
	#---------------------------------------------------------------------------

	return 0;
}


1;
