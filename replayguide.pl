#!C:/Perl/bin/perl.exe 
#[/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
# with bits by Philip Van Baren, Kanji T. Bates and Kevin J. Moye
#  $Id: replayguide.pl,v 1.30 2003/11/04 00:29:59 pvanbaren Exp $
#
# Requirements: 
#	XMLTV or DataDirect
#
#
# NOTE: If you have not read the INSTALL.txt or the prg.conf file please do so 
#       RIGHT NOW!
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
#------------------------------------------------------------------------------------
# NOTE: The more complex routines have special debug modes that can
#	be set by module.  Simply look for $specialdebug=0 near the
#	top of each routine and change to 1.   Logging goes to
#	the log file.  Warning: It can get *very* chatty.
#------------------------------------------------------------------------------------

use POSIX qw( strftime getcwd );
use CGI qw(:standard);
use Time::Local;

my $_version = "Personal ReplayGuide|Main|1|1|200|Lee Thompson,Philip Van Baren,Kevin J. Moye,Kanji T. Bates";

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

require 'rg_common.pl';			# Load common functions
require 'rg_database.pl';		# Load database functions
require 'rg_info.pl';			# Database Info
require 'rg_config.pl';			# Load config functions

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
# Set up any arrays
#------------------------------------------------------------------------------------

@productionrole = (
	"",
	"Actor",
	"Guest Star",
	"Host",
	"Director",
	"Producer",
	"Executive Producer",
	"Writer"
);

#-------------------------------------------------------------------
# Initialize and Load Configuration
#-------------------------------------------------------------------

$verbose = 0;
$scriptname = $script_pathname;
$configfile = "replayguide.conf";
$configstatus = &ReadConfig;

(my $parent,my $desc,my $major,my $minor,my $build,my $authors) = parseModuleData($prg_module{$module_name});

$program_title = $parent;
$program_module = $desc;
$program_author = buildMultiWordList($authors);
$program_version = "$major.$minor";
$program_build = $build;


$prg_start = time;

$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

CGI::import_names('input'); 

$RemoteAddress = $ENV{'REMOTE_ADDR'};

if ($RemoteAddress eq $null) {
	$RemoteAddress = "console";
}

#-------------------------------------------------------------------
# Check to see if the IP Address in $RemoteAddress has access to RTV
#-------------------------------------------------------------------

if (hasAccess($RemoteAddress)) {
	$rtvaccess = 1;
}else{	
	$rtvaccess = 0;
}


#-------------------------------------------------------------------
# Check to see if the IP Address in $RemoteAddress is set for PDA 
# mode
#-------------------------------------------------------------------

if (isPDA($RemoteAddress)) {
	$showpdaformat = 1;
}else{
	$showpdaformat = 0;
}

if (length($input::SHOWPDAFORMAT) > 0) {
	$showpdaformat = int $input::SHOWPDAFORMAT;
}


#-------------------------------------------------------------------------------------------
# Modify Settings to PDA Mode (If Needed)
#-------------------------------------------------------------------------------------------

if ($showpdaformat) {
	$size_pdalistings = "H5";	
	$defaultshowhours = 1;				# PDA mode only shows an hour 
	$showrtvtext = 1;				# Force Text
}

#-------------------------------------------------------------------------------------------
# Start it up!
#-------------------------------------------------------------------------------------------

writeDebug("********************************************************");
writeDebug("$program_title v$program_version (Build $program_build)");
writeDebug("Running as $script_pathname with PID $$");
writeDebug("Remote Address: $RemoteAddress ($rtvaccess)");
if ($verbose) {
	writeDebug("Console Output: Enabled");
}else{
	writeDebug("Console Output: Disabled");
}

if ($ENV{SERVER_SOFTWARE} ne $null) {
	writeDebug("Running on $ENV{SERVER_SOFTWARE}");
}

if ($showpdaformat) {
	writeDebug("PDA mode is ON");
}

if ($debug) {
	writeDebug("Debug Messages are ON");
}

&InitializeDisplay;

#-------------------------------------------------------------------
# Set up Database
#-------------------------------------------------------------------

&InitDB;
&InitDSN;

#-------------------------------------------------------------------
# Log what modules are loaded
#-------------------------------------------------------------------

identifyLoadedModules();

#-------------------------------------------------------------------
# Start Database
#-------------------------------------------------------------------


writeDebug("Start DSN->$DATASOURCE{DSN}");
writeDebug("If this is the last line in your log file you may have incorrectly configured the database.");
writeDebug("(Check prg.conf's [database] section, database.conf or rg_info.pl and the INSTALL.txt file for troubleshooting.)");

$prgdb_handle = &StartDSN;

if ($prgdb_handle ne $null) {
	writeDebug("Database Connection Established to $DATASOURCE{DSN} ($prgdb_handle)");
}else{
	writeDebug("Database Connection Failed to $DATASOURCE{DSN}");
	writeDebug("Reason: " .  &GetLastSQLError());
	writeDebug("(Check prg.conf's [database] section, database.conf or rg_info.pl and the INSTALL.txt file for troubleshooting.)");
	abend("Could not establish DSN ($DATASOURCE{DSN})");
}

#-------------------------------------------------------------------
# Set up Variables
#-------------------------------------------------------------------

$null = "";
$stars = "****";
$url_parms = "";

#-------------------------------------------------------------------
# Parse Input Fields 
#-------------------------------------------------------------------

if (length($ENV{'QUERY_STRING'}) > 0) {
	$default_mode = "";
}

$inp_startdate = $input::STARTDATE;
$inp_starthour = $input::STARTHOUR;
$inp_showhours = int $input::SHOWHOURS;
$inp_showslots = int $input::SHOWSLOTS;
$inp_firsttune = int $input::FIRSTTUNE;
$inp_lasttune = int $input::LASTTUNE;
$inp_favorite = $input::FAVORITE;
$inp_searchfield = $input::FIELD;
$inp_search = $input::SEARCH;
$inp_todo = filterfield($input::TODO);
$inp_programid = $input::PROGRAMID;
$inp_selectedrtv = $input::SELECTEDRTV;
$inp_recordtype = $input::RECORDTYPE;
$inp_updatedrtv = $input::UPDATE;
$inp_showsrtv = $input::SHOWSHOWS;
$inp_rtvunit = $input::RTVUNIT;
$inp_rtvaction = int $input::RTVACTION;
$inp_showdetail = $input::SHOWDETAIL;
$inp_deletertvshow = $input::DELETESHOW;
$inp_manualrec = $input::MANUALREC;
$inp_inputsource = $input::INPUTSOURCE;

writeDebug("CGI: STARTDATE: $inp_startdate");
writeDebug("CGI: STARTHOUR: $inp_starthour");
writeDebug("CGI: SHOWHOURS: $inp_showhours");
writeDebug("CGI: SHOWSLOTS: $inp_showslots");
writeDebug("CGI: FAVORITE: $inp_favorite");
writeDebug("CGI: SEARCHFIELD: $inp_searchfield");
writeDebug("CGI: FIRSTTUNE: $inp_firsttune");
writeDebug("CGI: LASTTUNE: $inp_lasttune");
writeDebug("CGI: SEARCH: $inp_search");
writeDebug("CGI: PROGRAMID: $inp_programid");
writeDebug("CGI: SELECTEDRTV: $inp_selectedrtv");
writeDebug("CGI: RECORDTYPE: $inp_recordtype");
writeDebug("CGI: UPDATE: $inp_updatedrtv");
writeDebug("CGI: RTVUNIT: $inp_rtvunit");
writeDebug("CGI: RTVACTION: $inp_rtvaction");
writeDebug("CGI: SHOWSHOWS: $inp_showsrtv");
writeDebug("CGI: SHOWDETAIL: $inp_showdetail");
writeDebug("CGI: DELETESHOW: $inp_deletertvshow");
writeDebug("CGI: MANUALREC: $inp_manualrec");
writeDebug("CGI: INPUTSOURCE: $inp_inputsource");
writeDebug("CGI: SHOWPDAFORMAT: $showpdaformat");



#-------------------------------------------------------------------
# If icons are not enabled clear them out
#-------------------------------------------------------------------

if ($showbuttonicons < 1) {
	$icon_schedule = "";
	$icon_now = "";
	$icon_go = "";
	$icon_locate = "";
	$icon_findall = "";
	$icon_findrepeat = "";
	$icon_all = "";
	$icon_locate = "";
	$icon_prevwindow = "";
	$icon_nextwindow = "";
	$icon_prevchan = "";
	$icon_nextchan = "";
	$icon_todo = "";
	$icon_find = "";
	$icon_select = "";
	$icon_schedule = "";
	$icon_done = "";
}

if ($showchannelicons < 1) {
	$image_stereo = "";
	$image_repeat = "";
	$image_cc = "";

	$image_tvg = "";
	$image_tvpg = "";
	$image_tv14 = "";
	$image_tvy = "";
	$image_tvy7 = "";
	$image_tvma = "";

	$image_mpaag = "";
	$image_mpaapg = "";
	$image_mpaapg13 = "";
	$image_mpaar = "";
	$image_mpaanc17 = "";
}


#-------------------------------------------------------------------
# Load Schedule Resolver Module (SRM) Plug-In 
#-------------------------------------------------------------------

writeDebug("Attempting to load $scheduler SRM module");

if (!fileExists($scheduler)) {
	writeDebug("Failed to load $scheduler SRM module");
	if (fileExists("rg_null.pl")) {
		writeDebug("Defaulting to rg_null.pl SRM module");
		$rtvaccess = 0;
	}else{
		abend("Could not load null SRM");
	}
}

if (!$rtvaccess) {
	$scheduler = "rg_null.pl";	# No RTV Access
}

writeDebug("Loading $scheduler SRM module");
require $scheduler;			# Functions handling scheduled recording display
identifyLoadedModules($scheduler);	# Ask SRM to ID itself
writeDebug(&AboutScheduler);		# 
$rtv_refreshinterval = &SchedulerDefaultRefresh;

if ($defaultrefreshinterval != -1) {
	if ($rtv_refreshinterval != $defaultrefreshinterval) {
		if ($rtv_refreshinterval > 0) {
			writeDebug("$scheduler forced guide refresh interval to $rtv_refreshinterval minutes");
		}else{
			if (&SchedulerDoBatchUpdate) {
				writeDebug("$scheduler disabled automatic guide refresh");
			}else{
				writeDebug("$scheduler does not support guide data");
			}
		}
	}
}else{
	if ($rtv_refreshinterval > 0) {
		writeDebug("$scheduler guide refresh interval set to $rtv_refreshinterval minutes");
	}else{
		writeDebug("$scheduler disabled automatic guide refresh");
	}
}

if ($rtv_refreshinterval > 0) {
	writeDebug("$scheduler is set to automatically refresh guide data every $rtv_refreshinterval minutes.");
}else{
	writeDebug("$scheduler automatic guide refresh is disabled.");
}

#-------------------------------------------------------------------
# Process ReplayTVs...
#-------------------------------------------------------------------
#
# This builds three sets of data structures for dealing with 
# ReplayTV units.
# 
# $replaylist is a comma delimited list of replayunits IDs.  These
# are ALL the ReplayTV units defined in the replayunits table.
#
# $schedulinglist is a semicolon delimited list of replay unit IDs.
# What makes this different from replaylist, is these are units that
# are capable of remote scheduling.   (If skipversioncheck is on
# this will always be the same as replaylist.)
#
# In addition there is a set of hash arrays for additional
# ReplayTV unit data.
#
#	$rtvlabel{REPLAYID}	Network Name (e.g. Office)
#	$rtvaddress{REPLAYID}	FQDN or IP Address of the RTV
#	$rtvport{REPLAYID}	Port number to use for the RTV
#	$rtvversion{REPLAYID}	ReplayTV Version
#	$guideversion{REPLAYID}	Guide Snapshot Version
#	$lastsnapshot{REPLAYID}	Epoch Seconds of Last Database Refresh
#	$categories{REPLAYID}	Semicolon delimited list of Categories
#				Cat #,Category Format
#	$rtvdefaultquality{ID}	Default quality level for ReplayID #
#	$rtvdefaultkeep{ID}	Default episodes to keep for ReplayID #
#
#	$rtvunit{LABEL}		Uses the Network Name and gives you
#				the replayid.
#
# Note if $rtvaccess is zero, none of this will be set!
#
#-------------------------------------------------------------------

$replaylist = "";
$schedulinglist = "";

if ($rtvaccess > 0) {
	writeDebug("Processing ReplayTVs...");

	my $need_update = 0;
	my $db_handle = &StartDSN;

	$Stmt = "SELECT * FROM $db_table_replayunits ORDER BY replayaddress;";

	my $sth = sqlStmt($db_handle,$Stmt);
	if($sth) {
		while ( my $row = $sth->fetchrow_hashref ) {

			my $replayid = $row->{'replayid'};

			$replaylist = buildcommastring($replaylist,$replayid);

			$rtvlabel{$replayid} = $row->{'replayname'};
			$rtvunit{$rtvlabel{$replayid}} = $replayid;
			$rtvaddress{$replayid} = $row->{'replayaddress'};
			$rtvport{$replayid} = $row->{'replayport'};
			$rtvversion{$replayid} = $row->{'replayosversion'};
			$rtvdefaultquality{$replayid} = int $row->{'defaultquality'};
			$rtvdefaultkeep{$replayid} = int $row->{'defaultkeep'};
			$guideversion{$replayid} = $row->{'guideversion'};
			$lastsnapshot{$replayid} = $row->{'lastsnapshot'};
			$categories{$replayid} = $row->{'categories'};
	
			#------------------------------------------
			# Any one of these criteria will force an
			# update.
			#------------------------------------------
			if ($row->{'lastsnapshot'} == 0) {
				$need_update = 1;
			}
			if ($rtvversion{$replayid} == 0) {
				$need_update = 1;
			}
			if ($guideversion{$replayid}== 0) {
				$need_update = 1;
			}
			if ($rtvport{$replayid} != 80) {
				writeDebug("Warning! $replayid) $rtvlabel{$replayid} at $rtvaddress{$replayid} has non standard port of $rtvport{$replayid}.  Integration functions may fail for this unit.");
			}

			if ($skipversioncheck) {
				if (length($schedulinglist) > 0) {
					$schedulinglist .= ";";
				}
				$schedulinglist .= "$replayid";
			}else{
				if ($guideversion{$replayid} == 2) {
					if (length($schedulinglist) > 0) {
						$schedulinglist .= ";";
					}
					$schedulinglist .= "$replayid";
				}
			}

		}
	}
	endDSN($sth,$db_handle);
	undef $db_handle;
	undef $sth;

	if ($replaylist eq $null) {
		writeDebug("No ReplayTVs defined.  ReplayTV functionality disabled.");
		$rtvaccess = 0;
		$inp_rtvaction = 0;
	}else{
		writeDebug(countArray($replaylist) . " ReplayTV units found:");
		for ( split /,/, $replaylist ) {
			/,/;
			writeDebug("$_) '$rtvlabel{$_}' at $rtvaddress{$_}");
		}

		if ($need_update) {
			$inp_updatedrtv = "ALL";
			writeDebug("$db_table_replayunits table has never been refreshed for 1 or more units, forcing update");
		}
	}

	#-------------------------------------------------------------------
	# Process RTVUNIT/ACTION
	#-------------------------------------------------------------------

	if ($inp_rtvaction > 0) {

		writeDebug("Processing ReplayTV Actions... ( $inp_rtvaction -> $inp_rtvunit )");

		if ($inp_rtvaction == 1) {
			#-------------------------------
			# Refresh
			#-------------------------------
			if ($inp_rtvunit > 0) {
				if (length($inp_updatertv) > 0) {
					$inp_updatedrtv = "ALL";
				}else{
					$inp_updatedrtv = $rtvaddress{$inp_rtvunit};
				}
			}else{
				$inp_updatedrtv = "ALL";
			}
		}

		if ($inp_rtvaction == 2) {
			#-------------------------------
			# To-Do List
			#-------------------------------
			$inp_todo = $inp_rtvunit;
		}

		if ($inp_rtvaction == 3) {
			#-------------------------------
			# Manage Shows/Channels
			#-------------------------------
			$inp_showsrtv = $inp_rtvunit;
		}

		if ($inp_rtvaction == 4) {
			#-------------------------------
			# Manual Recording
			#-------------------------------
			$inp_manualrec = $inp_rtvunit;
		}
	}


	
	if (length($inp_updatedrtv) > 0) {
		if ($rtv_updatesleepseconds) {
			writeDebug("Sleeping for $rtv_updatesleepseconds seconds to allow guidesnapshot(s) to show new recording on unit $inp_updatedrtv");
			sleep($rtv_updatesleepseconds);
			writeDebug("Awake");
		}
	}

	my $lastsnapshot = 0;
	my $right_now = time;
	my $addr;

	
	if ($rtvaccess > 0) {
		writeDebug("Checking ReplayTV guide data...");

		for ( split /,/, $replaylist ) {
			/,/;

			my $replayid = $_;
			my $refresh = 0;

			#-------------------------------------------------------------------
			# If the guide data is stale, get a fresh copy
			# if rtv_refreshinterval == 0, then only do manually forced refreshes
			# i.e. disable the autorefresh on time interval and after a scheduling change
			#-------------------------------------------------------------------

			if (($rtv_refreshinterval > 0) && (($right_now - $lastsnapshot{$replayid}) > ($rtv_refreshinterval * 60))) {
				writeDebug("$replayid) $rtvlabel{$replayid}: $rtv_refreshinterval is non-zero and snapshot is stale");
				$refresh = 1;
			}

			if (uc $inp_updatedrtv eq uc $rtvaddress{$replayid}) {
				writeDebug("$replayid) $rtvlabel{$replayid}: $rtvaddress{$replayid} matches $inp_updatedrtv, forcing getFreshScheduleTable");
				$refresh = 1;
			}

			if ($inp_updatedrtv eq 'ALL') {
				writeDebug("$replayid) $rtvlabel{$replayid}: $inp_updatedrtv set to ALL, forcing getFreshScheduleTable");
				$refresh = 1;
			}

			if ( $refresh ) {
				
				displayText("Refreshing $rtvlabel{$replayid} ... ",0,1);
				writeDebug("Attempting to refresh $rtvlabel{$replayid}");
				if(0 != getFreshScheduleTable($replayid)) {
					displayText("Failed\n");
					writeDebug("getFreshScheduleTable failed for $rtvlabel{$replayid}");
				} else {
					displayText("Complete\n");
					writeDebug("Refresh Complete");
					#-----------------------------------------
					# Update the snapshot time in the database
					#-----------------------------------------
					writeDebug("Attempting to update $rtvlabel{$replayid} snapshot marker");
					my $Update = "UPDATE $db_table_replayunits SET lastsnapshot = $right_now WHERE replayid = '$replayid';";
					my $db_handle = &StartDSN;

					if ( ! sqlStmt($db_handle,$Update) ) {
						displayText("ReplayTV database update Failed: <PRE>$Update\n" . &GetLastSQLError() . " \n</PRE>");
						writeDebug("Failed to update marker");
					}
					endDSN("",$db_handle);
					undef $db_handle;
					writeDebug("Finished processing RTV $rtvlabel{$replayid}");
				}
			} else {
				writeDebug("Refresh not required for $rtvlabel{$replayid}");
				if(0 != getCachedScheduleTable($replayid)) {
					writeDebug("getCachedScheduleTable failed for $rtvlabel{$replayid}");
					displayText("Failed to load cached schedule for $rtvlabel{$replayid}");
				}
			}
		}
	}

}else{
	writeDebug("No access to ReplayTV data.");
	$replaylist = "";
	$inp_updatedrtv = "";
}




#-------------------------------------------------------------------
# Prepare Time Calculations
#-------------------------------------------------------------------

$now_startdate = substr($now,0,4) . substr($now,5,2) . substr($now,8,2);
$now_starthour = int substr($now,11,2);
$now_timestring = substr($now,0,4) . substr($now,5,2) . substr($now,8,2) . substr($now,11,2) . substr($now,14,2) . "59";
$now_searchstart = substr($now,0,4) . substr($now,5,2) . substr($now,8,2) . substr($now,11,2) . "0000";
$now_todaystart = substr($now,0,4) . substr($now,5,2) . substr($now,8,2) . "000000";

if ($inp_startdate eq $null) {
	$inp_startdate = $now_startdate;
}

if ($inp_starthour eq $null) {
	$inp_starthour = $now_starthour;
} else {
	$inp_starthour = int $inp_starthour;
}

if ($inp_showhours < 1) {
	$inp_showhours = $defaultshowhours;
}

if ($inp_showslots < 1) {
	$inp_showslots = $defaultshowslots;
}

if (($primetime_start < 0) || ($primetime_start > 23)) {
	$primetime_start = 20;				# 8 PM
}

if (($inp_starthour < 0) || ($inp_starthour > 23)) {
	$inp_starthour = $now_starthour;
}


$starthour = sprintf("%02d",$inp_starthour);
$starttime = $inp_startdate . $starthour . "0000";

$startseconds = as_epoch_seconds($starttime);
$previousseconds = $startseconds - (($inp_showhours * 60) * 60);

$overlap = $startseconds + ($grid_end_overlap * 60);
$overlap = as_time_string($overlap);

$endseconds = $startseconds + (($inp_showhours * 60) * 60);

$previoustime = as_time_string($previousseconds);
$starttime = as_time_string($startseconds);
$endtime = as_time_string($endseconds);


#-------------------------------------------------------------------
# Ready Grid Settings
#-------------------------------------------------------------------

$maxpos = ($inp_showhours * 60) / $inp_showslots;
$maxpos = int $maxpos;

$colpos = 1;


#-------------------------------------------------------------------
# Get Channel Range
#-------------------------------------------------------------------

$Stmt = "";
$Stmt .= "SELECT * ";
$Stmt .= "FROM $db_table_channels ";
$Stmt .= "WHERE hidden = 0 ";
$Stmt .= "ORDER BY tuning;";

$records = 0;
$first_channel = 0;
$last_channel = 0;

my $db_handle = &StartDSN;

my $sth = sqlStmt($db_handle,$Stmt);
if ( $sth ) {

	while ( $row = $sth->fetchrow_hashref ) {
		$records++;
	
		if ($records == 1) {
			$firstrecord = int $row->{'tuning'};
		}
		
		$currentrecord = int $row->{'tuning'};
		$currentchannel = $row->{'channel'};
		$iconsrc = $row->{'iconsrc'};
		if($channelicondir && $iconsrc) { 
			$iconsrc =~ s|^.*/([^\/]+)$|$channelicondir/$1|;
		}
		$icon{$currentchannel} = $iconsrc;
		$tuningnumber{$currentchannel} = $currentrecord;
		$channel[$records] = $currentrecord . " " . $currentchannel;
		$tuning[$records] = $currentrecord;
	}

	$lastrecord = $currentrecord;
	$first_channel = $firstrecord;
	$last_channel = $lastrecord;
	$channelcount = $records;
}else{
	abend("Error building channel range");
}

endDSN($sth,$db_handle);
undef $db_handle;

if ($records == 0) {
	abend("No channels defined.\nHave you run updatetvdata yet?\nAlso check database configuration and/or datafeed configuration");
}

#------------------------------------------------------------------------
# For more than 12-hour displays, force to a single channel rotated table
#------------------------------------------------------------------------

if ($inp_showhours > 12) {
	$inp_lasttune = $inp_firsttune;
}

if ($inp_firsttune > $inp_lasttune) {
	$inp_firsttune = $first_channel;
}

if ($inp_lasttune < $inp_firsttune) {
	$inp_lasttune = $last_channel;
}


if ($inp_firsttune == 0) {
	$inp_firsttune = $first_channel;
}


if ($inp_lasttune == 0) {
	$inp_lasttune = $last_channel;
}


#-------------------------------------------------------------------
# Set up channel next/prev buttons
#-------------------------------------------------------------------

$records = 0;

do {
	$records++;
	if ($tuning[$records] == $inp_firsttune) {
		$first_rec = $records;
	}
	if ($tuning[$records] == $inp_lasttune) {
		$last_rec = $records;
	}
} while ($records < $channelcount);

$display_rec = ($last_rec - $first_rec) + 1;

if ($display_rec eq $channelcount) {
	$next_rec = 0;
	$prev_rec = 0;
}else{
	$next_chan = $tuning[$last_rec + 1];
	$prev_chan = $tuning[$first_rec - 1];

	if ($next_chan > $last_channel) {
		$next_chan = $last_channel;
	}

	if ($prev_chan < $first_channel) {
		$prev_chan = $first_channel;
	}

	$range_chan = $display_rec;

}

writeDebug("Channel Range is $first_channel to $last_channel ($channelcount)");

#-------------------------------------------------------------------
# Get First and Last date in the database
#-------------------------------------------------------------------

$selected_channel = $first_channel;
$channel_populated = 1;

my $db_handle = &StartDSN;
my $sth = "";

do {

	$Stmt = "";
	$Stmt .= "SELECT * ";
	$Stmt .= "FROM $db_table_tvlistings ";
	$Stmt .= "WHERE tuning = $selected_channel ";
	$Stmt .= "ORDER BY starttime;";

	$records = 0;

	$sth = sqlStmt($db_handle,$Stmt);
	if ( $sth ) {
		if (!$sth->fetchrow_hashref) {
		
			#------------------------------------------	
			# Channel has no data, try the next one.
			#------------------------------------------	

			$channel_populated = 0;
			$selected_channel++;
		}else{
			$channel_populated = 1;
		}
		
	}else{
		abend("Error building date range");
	}

	if ($selected_channel > $last_channel ) {
		abend("Error building date range, no data found.");
	}

} while ($channel_populated < 1);


while ( $row = $sth->fetchrow_hashref ) {
	$records++;
		
	if ($records == 1) {
		$firstrecord = sqltotimestring($row->{'starttime'});
	}
	
	$currentrecord = sqltotimestring($row->{'starttime'});
}
	
$lastrecord = $currentrecord;
$rng_startdate = substr($firstrecord,0,4) . substr($firstrecord,4,2) . substr($firstrecord,6,2);
$rng_stopdate = substr($lastrecord,0,4) . substr($lastrecord,4,2) . substr($lastrecord,6,2);

endDSN($sth,$db_handle);
undef $sth;
undef $db_handle;

#-------------------------------------------------------------------
# Set Date Boundaries
#-------------------------------------------------------------------

$rng_start = as_epoch_seconds($rng_startdate . "000000");
$rng_end = as_epoch_seconds($rng_stopdate . "000000") + 86400;
$prev_time = as_epoch_seconds($previoustime);
$next_time = as_epoch_seconds($endtime);
$dayone = timestringtosql(as_time_string($rng_start));

#-------------------------------------------------------------------
# Final Range Checks
#-------------------------------------------------------------------

if ($prev_time < $rng_start) {
	$prevok = 0;
}else{
	$prevok = 1;
}

if ($next_time > $rng_end) {
	$nextok = 0;
}else{
	$nextok = 1;
}

if (length($prev_chan) < 1) {
	$prev_chan = $first_channel;
}

if (length($next_chan) < 1) {
	$next_chan = $last_channel;
}


if ($prev_chan <= $first_channel) {
	$prevchanok = 0;
}else{
	$prevchanok = 1;
}

if ($next_chan >= $last_channel) {
	$nextchanok = 0;
}else{
	$nextchanok = 1;
}

writeDebug("Listings Range is $rng_startdate to $rng_stopdate");

displayText();

#-------------------------------------------------------------------
# See if Cast Crew Database is Populated
#-------------------------------------------------------------------

writeDebug("Checking castcrew table ($db_table_castcrew)");

$Stmt = "SELECT *";

if ($db_driver eq "ODBC") {
	$Stmt = "SELECT TOP 1 *";
}

$Stmt .= " FROM $db_table_castcrew";


if (($db_driver eq "SQLite") || ($db_driver eq "mysql"))  {
	$Stmt .= " LIMIT 1";
}


$Stmt .= ";";

$records = 0;

my $db_handle = &StartDSN;

my $sth = sqlStmt($db_handle,$Stmt);
if ( $sth ) {

	while ( $row = $sth->fetchrow_hashref ) {
		$records++;
	}
}else{
	my $lasterror = &GetLastSQLError();
	my $laststmt = &GetLastSQLStmt();

	writeDebug("$lasterror, $laststmt");

	#-----------------------------------
	# Quietly fail.
	#-----------------------------------
}

endDSN($sth,$db_handle);
undef $db_handle;

if ($records > 0) {
	writeDebug("Castcrew table ($db_table_castcrew) returned 1 record, use_castcrew enabled");

	$use_castcrew = 1;
}else{
	writeDebug("Castcrew table ($db_table_castcrew) did not return any records, use_castcrew disabled");

	$use_castcrew = 0;

}


#-------------------------------------------------------------------
# Display Toolbox
#-------------------------------------------------------------------

if ($showpdaformat) {
	&PDADisplayToolbox;
}else{
	&DisplayToolbox;
}

#-------------------------------------------------------------------
# Set SQL Format Times
#-------------------------------------------------------------------

$sql_start = timestringtosql($starttime);
$sql_end = timestringtosql($endtime);
$sql_overlap = timestringtosql($overlap);
$sql_now = timestringtosql($now_searchstart);
$sql_today = timestringtosql($now_todaystart);


#-------------------------------------------------------------------
# Collect ReplayTV Events
# If we are showing replay scheduling information,
# initialize the variables required for this
#-------------------------------------------------------------------
if ( $rtvaccess > 0 ) {
	&ProcessScheduleTable;
}

#-------------------------------------------------------------------
# Handle Modes
#-------------------------------------------------------------------

if (uc $default_mode eq 'NOW') {
		# Show Listings from now
}

if (uc $default_mode eq 'SEARCH') {
		#
		# Search Mode

		print "<$size_section><font face=\"$font_title\">Search Mode</$size_section><p></font>";

		&ShowFooter;
		exit(1);
}

if (uc $default_mode eq 'TODO') {
		if (&ToDoSupported) {	
			$inp_todo = "ALL";
		}
}

#-------------------------------------------------------------------
# Dispatch If Mode Has Changed
#-------------------------------------------------------------------

if (length($inp_programid) > 0) {
	writeDebug("Dispatch::ProgramDetails->$inp_programid");
	&DoSchedule;
	&ShowFooter;
	exit(1);
}

if (length($inp_search) > 0) {
	writeDebug("Dispatch::Search->$inp_search");
	displayHeading("Search Results:");
	&DoSearch;
	&ShowFooter;
	exit(1);
}

if (length($inp_todo) > 0) {
	writeDebug("Dispatch::ToDo->$inp_todo");
	displayHeading("To-Do List:");
	&DoToDo;
	&ShowFooter;
	exit(1);
}

if (length($inp_showsrtv) > 0) {
	writeDebug("Dispatch::ShowShows->$inp_showsrtv");
	showRTVShows($inp_showsrtv);
	&ShowFooter;
	exit(1);
}

if (length($inp_showdetail) > 0) {
	writeDebug("Dispatch::ShowDetail->$inp_showdetail");
	showDetail($inp_showdetail);
	&ShowFooter;
	exit(1);
}

if (length($inp_deletertvshow) > 0) {
	writeDebug("Dispatch::DeleteShow->$inp_deletertvshow");
	deleteRTVShow($inp_deletertvshow);
	&ShowFooter;
	exit(1);
}

if (length($inp_manualrec) > 0) {
	writeDebug("Dispatch::ManualRecord->$inp_manualrec");
	displayHeading("Schedule a Manual Recording");
	scheduleManualRecording($inp_manualrec);
	&ShowFooter;
	exit(1);
}



#-------------------------------------------------------------------
# Show Listings
#-------------------------------------------------------------------

print "<font face=\"$font_listings\">";

if ($showpdaformat) {
	
	#-----------------------------------------------------------------
	# Keep it as compact as possible, no table.
	#-----------------------------------------------------------------

}elsif ($inp_firsttune == $inp_lasttune) {
	
	#-----------------------------------------------------------------
	# If only a single channel or long time duration, rotate the table
	#-----------------------------------------------------------------

	print "<table border=1>";
}else{
	print "<table border=1>";

	$heading = "<tr><td width=10% align=center bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" size=2 color=\"$color_headingtext\"><B>Channel</B></font>\n";

	$ctr = 1;
	$blockstart = as_epoch_seconds($starttime);

	do {
		$heading .= "<td width=15% align=center bgcolor=\"$color_headingbackground\"><font size=2 face=\"$font_heading\" color=\"$color_headingtext\"><B>\n";
		$heading .= as_hhmm($blockstart);
		$heading .= "</B></font>";
		$blockstart = $blockstart + ($inp_showslots * 60);
		$ctr++;

	} while ($ctr < $maxpos+1);

	$heading .= "</tr>\n";

	print $heading;
}

#-------------------------------------------------------------------
# We print out the heading at the start and bottom, it would be
# trivial to add the heading every N rows.
#-------------------------------------------------------------------

$Stmt = "";

if ($showpdaformat) {
	$Stmt .= "SELECT * ";
	$Stmt .= "FROM $db_table_tvlistings, $db_table_channels ";
	$Stmt .= "WHERE ((((starttime < '$sql_end') AND (endtime > '$sql_start') ";
	if( $inp_favorite ) {
		$Stmt .= "AND $db_table_tvlistings.tuning IN ($favorites{$inp_favorite})) ";
	} else {
		$Stmt .= "AND $db_table_tvlistings.tuning BETWEEN $inp_firsttune AND $inp_lasttune) ";
	}
	$Stmt .= "AND $db_table_tvlistings.tuning = $db_table_channels.tuning) ";
	$Stmt .= "AND $db_table_tvlistings.channel = $db_table_channels.channel) ";
	$Stmt .= "AND $db_table_channels.hidden = 0 ";
	$Stmt .= "ORDER BY starttime, $db_table_tvlistings.tuning;";
}else{
	$Stmt .= "SELECT * ";
	$Stmt .= "FROM $db_table_tvlistings, $db_table_channels ";
	$Stmt .= "WHERE ((((starttime < '$sql_end') AND (endtime > '$sql_start') ";
	if( $inp_favorite ) {
		$Stmt .= "AND $db_table_tvlistings.tuning IN ($favorites{$inp_favorite})) ";
	} else {
		$Stmt .= "AND $db_table_tvlistings.tuning BETWEEN $inp_firsttune AND $inp_lasttune) ";
	}
	$Stmt .= "AND $db_table_tvlistings.tuning = $db_table_channels.tuning) ";
	$Stmt .= "AND $db_table_tvlistings.channel = $db_table_channels.channel) ";
	$Stmt .= "AND $db_table_channels.hidden = 0 ";
	$Stmt .= "ORDER BY $db_table_tvlistings.tuning, $db_table_tvlistings.channel, starttime;";
}

if ($debug) {
	print "<PRE>SQL: $Stmt\n</PRE>";
}


$records = 0;
$hdr_ctr = 0;
$debug_state = 0;
$end_row = 1;

if ($rtvaccess > 0) {

	#-------------------------------------------------------------------
	# If we are showing replay scheduling information,
	# compare the scheduled event list against the displayed event list
	#-------------------------------------------------------------------

	if ($debug) {
		writeDebug("Attempting to Comparing Event Tables");
	}

	compareScheduleTable($Stmt);

	if ($debug) {
		writeDebug("Comparing Event Tables Completed");
	}
}

writeDebug("Display Grid for $sql_start through $sql_end");
writeDebug("Display Grid with $inp_showslots minute slots");

if($inp_favorite) {
	writeDebug("Display Grid containing channels $favorites{$inp_favorite}");
} else {
	writeDebug("Display Grid containing channels $inp_firsttune - $inp_lasttune");
}

$records = 0;
$hdr_ctr = 0;
$debug_state = 0;
$end_row = 1;
$previous_date = "";

#-------------------------------------------------------------------
# Display scheduled recordings at the top
#-------------------------------------------------------------------

if (&SchedulebarSupported) {
	writeDebug("Display Options: Schedule Bar: $showschedulebar");
}else{
	if ($showschedulebar) {
		writeDebug("$scheduler does not support the schedulebar, disabled.");
	}
	$showschedulebar = 0;
}

writeDebug("Display Options: PDA Format: $showpdaformat");

if ( $rtvaccess && $showschedulebar && !$showpdaformat  
    && ($inp_firsttune != $inp_lasttune)) {
	writeDebug("Schedulebar Enabled");	


	#-----------------------------------------------------------
	# If you would rather have LOCATE find the show in the 
	# schedulebar, change $create_anchor to a 1.
	#-----------------------------------------------------------
	
	my $specialdebug = 0;

	$create_anchor = 0;

	my $db_handle = &StartDSN;

	my $sth = "";

	for ( split /,/, $replaylist ) {
		/,/;
		$displayunitlabel = $rtvlabel{$_};
		if( ! $displayunitlabel ) {
			$displayunitlabel = $rtvaddress{$_};
			if( ! $displayunitlabel ) {
				$displayunitlabel = $_;
			}
		}

		writeDebug("Creating schedule bar for '$displayunitlabel'");

		for( $conflict = 0; $conflict < 2; $conflict++) {
	
			$Stmt2 = "SELECT * FROM $db_table_schedule,$db_table_tvlistings ";
			$Stmt2 .= "WHERE (replayid = $_) ";
			$Stmt2 .= "AND ($db_table_schedule.programid = $db_table_tvlistings.programid) ";
			$Stmt2 .= "AND ($db_table_schedule.conflict = $conflict) ";
			$Stmt2 .= "AND ($db_table_tvlistings.starttime < '$sql_end') ";
		        $Stmt2 .= "AND ($db_table_tvlistings.endtime > '$sql_start') ";
			$Stmt2 .= "ORDER BY $db_table_tvlistings.starttime;";

			if ($specialdebug) {
				writeDebug("SQL: $Stmt2");
			}

			if( $conflict ) {
				$displayunitlabel .= " (conflicts)";
			}
			$sth = sqlStmt($db_handle,$Stmt2);
			if ( $sth ) {
			    while ( $row = $sth->fetchrow_hashref ) {
				$temp_value = 0;
				$length_offset = 0;
	
				$program_id = $row->{'programid'};

				$program_start = sqltotimestring($row->{'starttime'});
				$program_true_start = $program_start;
				$program_stop = sqltotimestring($row->{'endtime'});
				$program_title = $row->{'title'};
				$program_subtitle = $row->{'subtitle'};
				$program_desc = $row->{'description'};
				$program_tuning = $row->{'tuning'};
				$program_channel = $row->{'channel'};
				$program_advisories = $row->{'advisories'};
				$program_category = $row->{'category'};
				$program_mpaarating = $row->{'mpaarating'};
				$program_vchiprating = $row->{'vchiprating'};
				$program_episodenum = $row->{'episodenum'};
				$program_movieyear = int $row->{'movieyear'};
				$program_stereo = int $row->{'stereo'};
				$program_repeat = int $row->{'repeat'};
				$program_starrating = $row->{'starrating'};
				$program_captions = $row->{'captions'};
				$program_theme = $row->{'theme'};
				$program_icon = "";

				($program_stars,$junk) = split(/\//,$program_starrating);

				$program_beforepad = $row->{'padbefore'};
				$program_afterpad = $row->{'padafter'};


				if ($specialdebug) {
					writeDebug("Scheduled program: $program_title  Padding: ($program_beforepad, $program_afterpad)");
				}

				#----------------------------------------------------------------------------
				# Because in it's infinite wisdom XMLTV does not provide a STOP time
				# at the end of the listings, if we're looking at the last available
				# data we can't calculate an endpoint so we just make something up.
				# (Basically we give it one slot)
				#----------------------------------------------------------------------------

				$fudged_length = 0;

				if (as_epoch_seconds($program_stop) < as_epoch_seconds($program_start)) {
					$program_stop = as_time_string(as_epoch_seconds($program_start) + ($inp_showslots * 60));
					$fudged_length = 1;
				}

				#----------------------------------------------------------------------------
				# Fudge the program start and stop times by the padding factors
				#----------------------------------------------------------------------------
				# Only fudge grid for the schedulebar if the padding is significant
				#----------------------------------------------------------------------------

				if ( ( $program_beforepad > $inp_showslots ) || ( $program_afterpad > $inp_showslots) ) {
					if( $program_beforepad ) {
						writeDebug("Adjusting start time to account for $program_beforepad minutes of padding");
						$program_start = as_time_string(as_epoch_seconds($program_start) - ($program_beforepad * 60));
					}
					if( $program_afterpad ) {
						writeDebug("Adjusting stop time to account for $program_afterpad minutes of padding");
						$program_stop = as_time_string(as_epoch_seconds($program_stop) + ($program_afterpad * 60));
					}
				}

				#----------------------------------------------------------------------------
				# Make sure the fudged times still match the displayed interval
				#----------------------------------------------------------------------------
				if( (as_epoch_seconds($program_start) > as_epoch_seconds($endtime))
					|| (as_epoch_seconds($program_stop) < as_epoch_seconds($starttime)) ) {
					next;
				}

				$records++;
				$program_length = getMinutes($program_start,$program_stop);
				$display_length = $program_length;
				$program_time = "";
				$program_extra = "";

				$rng_string = substr(as_time_string(as_epoch_seconds($program_true_start)),0,8);
				$wday = strftime( "%A", localtime(as_epoch_seconds($program_true_start)));
				$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2) . "/" . substr($rng_string,0,4);
			
				$program_starthour = substr($program_start,8,2);
				$program_startdate = substr($program_start,0,8);

				$starttime = $inp_startdate . $starthour . "0000";

        			if (as_epoch_seconds($program_stop) < as_epoch_seconds($now_timestring))  {
        			        # Past show
					$program_timing = 0;
				}elsif (as_epoch_seconds($program_start) < as_epoch_seconds($now_timestring))  {
        		    	    	# Current show
					$program_timing = 1;
		        	} else {
              		  		# Future show
					$program_timing = 2;
				}
				&DisplayListings;
			    }
			}
		}
	}
	if( $records > 0 ) {

		#----------------------------------------------------------
		# If we showed the schedule bar, force another header bar
		# to give a separator between the schedule bar and programs
		#----------------------------------------------------------

		$hdr_ctr = -1;
	}
	endDSN($sth,$db_handle);
	undef $db_handle;
	writeDebug("Schedulebar Complete");

}

#----------------------------------------------------------------------------
# End the schedulebar type display format in displaylistings
# and reset the display counters so we get another time bar as a separator
#----------------------------------------------------------------------------

$shortslot = 0;
$max_span = 0;
$previous_display = 0;
$force_new_column = 0;
$debug_state = 0;
$previous_date = "";
$displayunitlabel = "";
$create_anchor = 1;

#$records = 0;  # Don't reset this, because it would inhibit drawing a separator header bar
#$end_row = 1;  # Don't set this, because we may need to clean up the previous row


#-------------------------------------------------------------------
# Get Data from SQL and Display Grid
#-------------------------------------------------------------------

writeDebug("SQL: $Stmt");

my $sth = sqlStmt($prgdb_handle,$Stmt);
if ( $sth ) {

	while ( $row = $sth->fetchrow_hashref ) {
		$temp_value = 0;
		$length_offset = 0;

		$records++;

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
		$program_theme = $row->{'theme'};
		$program_icon = "";

		($program_stars,$junk) = split(/\//,$program_starrating);


		#-------------------------------------------------------------------
		# If we have a duplicate record, skip  (more of a sanity check)
		#-------------------------------------------------------------------

		if ($program_id eq $prev_id) {
			next;
		}

		#-------------------------------------------------------------------
		# Because in it's infinite wisdom XMLTV does not provide a STOP time
		# at the end of the listings, if we're looking at the last available
		# data we can't calculate an endpoint so we just make something up.
		# (Basically we give it one slot)
		#-------------------------------------------------------------------

		$fudged_length = 0;

		if (as_epoch_seconds($program_stop) < as_epoch_seconds($program_start)) {
			$program_stop = as_time_string($rng_end);
			$fudged_length = 1;
		}

		#-------------------------------------------------------------------
		# Prepare Variables and Calculate Running Time
		#-------------------------------------------------------------------

		$program_length = getMinutes($program_start,$program_stop);
		$display_length = $program_length;
		$program_time = "";
		$program_extra = "";

		#-------------------------------------------------------------------
		# Handle programming that's partially visible on the grid
		#-------------------------------------------------------------------

		if (as_epoch_seconds($program_start) < as_epoch_seconds($starttime))  {
			$program_start = $starttime;
			$program_length = getMinutes($program_start,$program_stop);
		}			
	
		if (as_epoch_seconds($program_stop) > as_epoch_seconds($endtime))  {
			$program_true_stop = $program_stop;
			$program_stop = $endtime;
			$program_length = getMinutes($program_start,$program_stop);
			if (length($program_extra) > 0) {
				$program_extra .= " (continues until " . displaytime($program_true_stop) . ")";
			}else{
				$program_extra = "(continues until " . displaytime($program_true_stop) . ")";
			}

		}
		
		#-------------------------------------------------------------------
		# Activate tvgrid driver
		#-------------------------------------------------------------------

		if ($showpdaformat) {
			if ($inp_firsttune == $inp_lasttune) {
				&PDASingleChannelListings;
			}else{
				&PDADisplayListings;
			}
		}else{
			if ($inp_firsttune == $inp_lasttune) {
				&SingleChannelListings;
			}else{
				if ($records == 1) {
					$dl_lasttuning = $program_tuning;
				}

				&DisplayListings;
			}

		}

		#-------------------------------------------------------------------
		# Set up sanity check
		#-------------------------------------------------------------------

		$prev_id = $program_id;

	}

}else{
	#-------------------------------------------------------------------
	# Something Went Amiss
	#-------------------------------------------------------------------

	writeDebug("Fatal Error: " . &GetLastSQLStmt() . " / " . &GetLastSQLError() );
	print "<p>Fatal Error!<p><PRE>Query Failed: " . &GetLastSQLStmt() . "\n" .  &GetLastSQLError() . "</PRE><p>";
}

if ($records) {
	if ($showpdaformat) {
	}elsif ($inp_firsttune != $inp_lasttune) {
		print "</table>\n";
	} else {
		if (!$end_row) {
			$colspan = ($maxpos+1) - $colpos;
			print "<td colspan=$colspan align=left valign=top bgcolor=$color_show[0]>";
			print "</td></tr>\n";
		}

		if ($hdr_ctr > 1) {
			print $heading;
		}
		print "</table>\n";
	}
	print "</font>\n";
	writeDebug("TV Listings Returned $records Rows");

}else{
	writeDebug("TV Listings SQL Query Returned No Rows");
	print "<tr><td><td colspan=$maxpos align=center><$size_title>No data</center></$size_title></table></font>";
}

&ShowFooter;

#---------------------------------------------------------------------------------------
# FUNCTIONS ****************************************************************************
#---------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------
sub PDADisplayListings{
	#
	# Display Program Listings (PDA Format)
	# aka. This is a lot easier than a program grid
	#
	#-------------------------------------------------------------------------------

	$curr_date = substr($program_start,0,8);
	$curr_time = $program_start;

	if ($prev_date ne $curr_date) {
		if ($records > 1) {
			print "<p>\n";		
		}
		$wday = strftime( "%A", localtime(as_epoch_seconds($program_start)));
		$dsp_string = $wday . ", " . substr($curr_date,4,2) . "/" . substr($curr_date,6,2) . "/" . substr($curr_date,0,4);
		print "<B>$dsp_string</B><p>\n";
	}

	if ($prev_time != $curr_time) {
		if ($records > 1) {
			print "<p>\n";
		}
		print "<$size_pdalistings>";
		print as_hhmm(as_epoch_seconds($program_start));
		print "<br>";
	}

	print "<$size_pdalistings>$program_tuning ";

	print "<a ";

	if ($create_anchor) {
		print "name=\"$program_id\" ";
	}

	$url_parms = "";
	addParameter("PROGRAMID",$program_id);
	addParameter("STARTDATE",$inp_startdate);
	addParameter("STARTHOUR",$inp_starthour);
	addParameter("SHOWHOURS",$inp_showhours);
	addParameter("SHOWSLOTS",$inp_showslots);
	addParameter("SHOWPDAFORMAT",$showpdaformat);

	print "	href=\"$scriptdir/$scriptname$url_parms\">\n";

	print renderhtml($program_title);
	print "\n</a>";

	if ($program_length > 30) {
		print " <small>" . getRunningTime($display_length) . "</small>";
	}

	print "<br>\n";

	$prev_date = $curr_date;
	$prev_time = $curr_time;

	return 1;
}


#---------------------------------------------------------------------------------------
sub PDADisplayToolbox{
	#
	# Show Toolbox (PDA Format)
	#
	#-------------------------------------------------------------------------------

	print "<center><font face=\"$font_menu\">";
	print "<table border=0><tr><td>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=\"STARTDATE\" value=\"$now_startdate\">\n";
	print "<input type=hidden name=\"STARTHOUR\" value=\"$now_starthour\">\n";
	print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
	print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";

	if (length($icon_now) > 0) {
		print "<input type=image src=\"$imagedir/$icon_now\" ALT=\"Now\">\n";
	}else{
		print "<input type=submit value=\"NOW\" name=\"SUBMIT2\">\n";
	}
	print "</form><td>";

	print "<center>";
	print "<font face=\"$font_menu\">";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=\"STARTDATE\" value=\"$now_startdate\">\n";
	print "<input type=hidden name=\"STARTHOUR\" value=\"$prime_start\">\n";
	print "<input type=hidden name=\"SHOWHOURS\" value=\"$defaultshowhours\">\n";
	print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
	if (length($icon_tonight) > 0) {
		print "<input type=image src=\"$imagedir/$icon_tonight\" ALT=\"Prime\">\n";
	}else{
		print "<input type=submit value=\"Prime\" name=\"SUBMIT4\">\n";
	}
	print "</form>";

	$form_date = substr($previoustime,0,4) . substr($previoustime,4,2) . substr($previoustime,6,2);
	$form_time = substr($previoustime,8,2);

	print "<td>";

	if ($prevok) {
		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$form_date\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$form_time\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
		print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";

		if (length($icon_prevwindow) > 0) {
			print "<input type=image src=\"$imagedir/$icon_prevwindow\" ALT=\"<<<\">\n";
		}else{
			print "<input type=submit value=\"<<<\" name=\"SUBMITPW\">";
		}

		print "</form>\n\n";
	}

	print "<td>";

	$form_date = substr($endtime,0,4) . substr($endtime,4,2) . substr($endtime,6,2);
	$form_time = substr($endtime,8,2);

	if ($nextok) {
		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$form_date\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$form_time\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
		print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";

		if (length($icon_nextwindow) > 0) {
			print "<input type=image src=\"$imagedir/$icon_nextwindow\" ALT=\">>>\">\n";
		}else{
			print "<input type=submit value=\">>>\" name=\"SUBMITNW\">\n";
		}

		print "</form>\n\n";
	}



	print "</table>\n ";

	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "Date: <select size=\"1\" name=\"STARTDATE\">\n";

	do {
		$rng_string = substr(as_time_string($rng_start),0,8);
		$wday = strftime( "%A", localtime($rng_start));
		$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2) . "/" . substr($rng_string,0,4);
		print "<option value=\"$rng_string\"";
		if ($rng_string eq substr($starttime,0,4) . substr($starttime,4,2) . substr($starttime,6,2)) {
			print " selected";
		}
		print ">$dsp_string</option>\n";

		$rng_start = $rng_start + 86400;
		$ctr++;

	} while ($rng_start < $rng_end);
	print "</select>\n";
	print "<br>";

	print "Time: ";
	print "<select size=\"1\" name=\"STARTHOUR\">\n";

	$ctr = 0;
	do {
		$dsp_string = as_ampm($ctr);
		print "<option value=\"$ctr\"";
		if ($ctr == int substr($starttime,8,2)) {
			print " selected";
		}
		print ">$dsp_string</option>\n";
		$ctr++;

	} while ($ctr < 24);
	print "</select>\n";

	print " ";

	if (length($icon_go) > 0) {
		print "<input type=image src=\"$imagedir/$icon_go\" ALT=\"Go\">\n";
	}else{
		print "<input type=submit value=\"Go\" name=\"SUBMITGO\">";
	}
	print "</form>\n";

	print "<br>\n";

	
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
	print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
	print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
	print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
	print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
	print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
	print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";
	print "<input type=text name=\"SEARCH\" value=\"\" size=20>\n";
	print "<br>";
	print "<select size=\"1\" name=\"FIELD\">\n";
	print "<option value=\"title\" selected>Title</option>\n";
	print "<option value=\"subtitle\">Episode</option>\n";
	print "<option value=\"description\">Desc.</option>\n";
	print "<option value=\"category\">Genre</option>\n";
	print "<option value=\"advisories\">Alerts</option>\n";

	if ($use_castcrew) {
		print "<option value=\"1\">Actor</option>\n";
		print "<option value=\"2\">Guest</option>\n";
		print "<option value=\"3\">Host</option>\n";
		print "<option value=\"4\">Director</option>\n";
		print "<option value=\"5\">Producer</option>\n";
		print "<option value=\"6\">Exec.</option>\n";
		print "<option value=\"7\">Writer</option>\n";
	}

	print "</select>\n";

	if (length($icon_find) > 0) {
		print "<input type=image src=\"$imagedir/$icon_find\" ALT=\"Find\">\n";
	}else{
		print "<input type=submit value=\"Find\" name=\"SUBMITFIND\">\n";
	}

	print "</form>";


	my $s_todo = &ToDoSupported;
	my $s_guide = 0;

	if ($rtvaccess) {
		$s_guide = 1;

	}

	if ($rtvaccess) {
		print "<td valign=top>RTV:\n";
		print "<td valign=top><form action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
		print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";
		print "<select size=\"1\" name=\"RTVUNIT\">\n";
		for ( split /,/, $replaylist ) {
			/,/;
			my $addr = $rtvaddress{$_};
			my $label = $rtvlabel{$_};
			print "<option value=$_";
			print ">$label</option>\n";
		}
		print "<option value=0 selected>ALL</option>\n";
		print "</select>\n";

		print "<select size=\"1\" name=\"RTVACTION\">\n";
		print "<option value=-1 selected>Action?</option>\n";
		if ($s_guide) {
			print "<option value=1>Refresh</option>\n";
		}
		if ($s_todo) {
			print "<option value=2>To-Do</option>\n";
		}
		if ($s_guide) {
			print "<option value=3>Manage</option>\n";
		}
		if ($s_guide) {
			print "<option value=4>Manual</option>\n";
		}
		print "</select>\n";

		if (length($icon_go) > 0) {
			print "<input type=image src=\"$imagedir/$icon_go\" ALT=\"Go\">\n";
		}else{
			print "<input type=submit value=\"Go\" name=\"SUBMITRTV\">\n";
		}	
		print "</form>\n";
	}

	print "</center><center>\n";

	return 1;
}


#---------------------------------------------------------------------------------------
sub PDASingleChannelListings{
	#
	# Display Program Listings (Single Channel vertical format)
	#
	#-------------------------------------------------------------------------------

	my $specialdebug = 0;					# Enable Debug Logging

	if ($specialdebug) {
		writeDebug("PDASingleChannelListings::$program_tuning $program_title $program_start $program_id");
	}

	#------------------------------------------------------------
	# When the date advances, display the header again
	#------------------------------------------------------------

	$rng_string = substr(as_time_string(as_epoch_seconds($program_true_start)),0,8);
	$wday = strftime( "%A", localtime(as_epoch_seconds($program_true_start)));
	$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2) . "/" . substr($rng_string,0,4);

	if( $dsp_string ne $previous_date ) {
		print "<$size_pdalistings><B>$dsp_string ($program_tuning $program_channel)</B><p>\n";
		$previous_date = $dsp_string;
	}

	#------------------------------------------------------------
	# Display the start time to the left of each show
	#------------------------------------------------------------

	print as_hhmm(as_epoch_seconds($program_true_start)) . "<br>";

	#------------------------------------------------------------
	# Force some variables so the odd start times aren't duplicated in the render
	#------------------------------------------------------------

	$starttime = $program_true_start;
	$colpos = 1;
	$colspan = 1;
	$shortslot = 0;

	print "<a ";

	if ($create_anchor) {
		print "name=\"$program_id\" ";
	}

	$url_parms = "";
	addParameter("PROGRAMID",$program_id);
	addParameter("STARTDATE",$inp_startdate);
	addParameter("STARTHOUR",$inp_starthour);
	addParameter("SHOWHOURS",$inp_showhours);
	addParameter("SHOWSLOTS",$inp_showslots);
	addParameter("SHOWPDAFORMAT",$showpdaformat);

	print "	href=\"$scriptdir/$scriptname$url_parms\">\n";

	print renderhtml($program_title);
	print "\n</a>";

	if ($program_length > 30) {
		print " <small>" . getRunningTime($display_length) . "</small>";
	}

	print "<br>\n";


	#-------------------------------------------------------------------
	# Only one show per row
	#-------------------------------------------------------------------

	$rows++;

	if ($specialdebug) {
		writeDebug("PDASingleChannelListings::(exiting)");
	}

	return 1;
}
	
#---------------------------------------------------------------------------------------
sub SingleChannelListings{
	#
	# Display Program Listings (Single Channel vertical format)
	#
	#-------------------------------------------------------------------------------

	my $specialdebug = 0;					# Enable Debug Logging

	if ($specialdebug) {
		writeDebug("SingleChannelListings::$program_tuning $program_title $program_start $program_id CP: $colpos ER: $end_row");
	}

	#------------------------------------------------------------
	# When the date advances, display the header again
	#------------------------------------------------------------

	$rng_string = substr(as_time_string(as_epoch_seconds($program_true_start)),0,8);
	$wday = strftime( "%A", localtime(as_epoch_seconds($program_true_start)));
	$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2) . "/" . substr($rng_string,0,4);

	if( $dsp_string ne $previous_date ) {
		print "<tr><td width=10% align=center bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" size=2 color=\"$color_headingtext\"><B>$dsp_string</B></font>\n";
		print "<td align=center bgcolor=\"$color_channelbackground\">";
		if ($showchannelicons > 0) {
			if (length($icon{$program_channel}) > 0) {
				print "<img src=$icon{$program_channel}><br>";
			}
		}
		print "<font size=2 face=\"$font_channel\" color=\"$color_channeltext\"><B>$program_tuning<br>$program_channel</B></font>\n";
		print "</td></tr>\n";
		$previous_date = $dsp_string;
	}

	#------------------------------------------------------------
	# Display the start time to the left of each show
	#------------------------------------------------------------

	print "<TR><TD>" . as_hhmm(as_epoch_seconds($program_true_start)) . "</TD>\n";

	#------------------------------------------------------------
	# Force some variables so the odd start times aren't duplicated in the render
	#------------------------------------------------------------

	$starttime = $program_true_start;
	$colpos = 1;
	$colspan = 1;
	$shortslot = 0;
	
	#-------------------------------------------------------------------
	# Render the show data
	#-------------------------------------------------------------------
	&RenderShow;

	#-------------------------------------------------------------------
	# Only one show per row
	#-------------------------------------------------------------------

	$rows++;
	print "</tr>\n";

	if ($specialdebug) {
		writeDebug("SingleChannelListings::(exiting)");
	}

	return 1;
}

#---------------------------------------------------------------------------------------
sub DisplayListings{
	#
	# Display Program Listings
	#
	#-------------------------------------------------------------------------------

	my $specialdebug = 0;					# Enable Debug Logging


	#-------------------------------------------------------------------------------
	# Precalculate epoch seconds for a number of fields, $es_ means epoch seconds.
	# (Duh).   You can get HH:MM with as_hhmm($es_blah)
	#-------------------------------------------------------------------------------

	$es_program_true_start = as_epoch_seconds($program_true_start);
	$es_program_start = as_epoch_seconds($program_start);
	$es_program_stop = as_epoch_seconds($program_stop);
	$es_starttime = as_epoch_seconds($starttime);
	$es_endtime = as_epoch_seconds($endtime);

	&CalculateSlotTimes;

	#-------------------------------------------------------------------------------
	# These will contain "previous" position data.
	#-------------------------------------------------------------------------------

	$tmp_slotstart = $es_slotstart;
	$tmp_shortslot = $shortslot;
	$tmp_colspan = $colspan;
	$tmp_colpos = $colpos;

	my $clean_up = 0;

	#-------------------------------------------------------------------------------
	# Vomit debug information.
	#-------------------------------------------------------------------------------
	
	if ($specialdebug) {
		writeDebug("DisplayListings::START***");
		writeDebug("DisplayListings::Starting processing for timeslot " . as_hhmm($es_slotstart) . " $es_slotstart )");
		writeDebug("DisplayListings::$program_tuning $program_title $program_start $program_id CP: $colpos ER: $end_row CL: $clean_up TM: $total_minutes PD: $previous_display");
		writeDebug("DisplayListings:: Program True: " . as_hhmm($es_program_true_start) . " $es_program_true_start $program_true_start ");
		writeDebug("DisplayListings::Program Start: " . as_hhmm($es_program_start) . " $es_program_start $program_start ");
		writeDebug("DisplayListings:: Program Stop: " . as_hhmm($es_program_stop) . " $es_program_stop $program_stop ");
		writeDebug("DisplayListings:: Current Slot: " . as_hhmm($es_slotstart) . " $es_slotstart");
		writeDebug("DisplayListings::    Next Slot: " . as_hhmm($es_nextslot) . " $es_nextslot");
		writeDebug("DisplayListings::Previous Slot: " . as_hhmm($es_prevslot) . " $es_prevslot");
		writeDebug("DisplayListings:: Window Start: " . as_hhmm($es_starttime) . " $es_starttime");
		writeDebug("DisplayListings::   Window End: " . as_hhmm($es_endtime) . " $es_endtime");

	}


	#-------------------------------------------------------------------------------
	# See if we are the start of a row, if the previous row ended early, grey out
	# the remainder with the pastshow color.
	#-------------------------------------------------------------------------------
	
	if(($colpos > 1) && !$shortslot && ($es_program_start > $es_slotstart) ) {

		#-------------------------------------------------------------------
		# If we have a gap in the data, fill with blank columns
		# This happens primarily for scheduled programs
		# (colpos = 1 case is handled later, when we start a new column)
		# ??? If total_minutes < inp_showslots, then we simply have a case of short programs
		# ??? in which case we don't want any extra padding
		#-------------------------------------------------------------------

		local($temp_value) = $es_program_start - $es_slotstart;
		local($temp_value) = int $temp_value / 60;

		if ($temp_value < $inp_showslots) {	
			# Should be alright
		}else{
			if ($colpos < $maxpos) {

				#-------------------------------------------------------------------
				# nearly truncate so we don't leave too much of a gap
				#-------------------------------------------------------------------

				$colspan = sprintf("%.0f",$temp_value / $inp_showslots - 0.4);

				if( $colspan > 0 ) {
					if ($specialdebug) {
						writeDebug("DisplayListings::Filling with $colspan columns because program $program_title starts $temp_value minutes late");
						writeDebug("DisplayListings::program_start = $program_start, starttime = $starttime, colpos = $colpos, showslots = $inp_showslots");
					}
	
					print "<td colspan=$colspan align=left valign=top bgcolor=$color_show[0]>\n";
					$colpos += $colspan;
					$td_ctr += $colspan;
				}
			}
		}
	}


	if ( ( $displayunitlabel && ($dl_lasttuning ne $displayunitlabel))
	  || (!$displayunitlabel && ($dl_lasttuning != $program_tuning)) ) {
		if (!$end_row) {
			$colspan = ($maxpos+1) - $colpos;
			print "<td colspan=$colspan align=left valign=top bgcolor=$color_show[0]>";
			print "</td>\n";
			if ($specialdebug) {
				writeDebug("DisplayListings::prior row adjusted ($dl_lasttuning != $program_tuning)");
			}
			$colpos = 1;
			$end_row = 1;
		}
		$clean_up = 1;
	}else{
		if ($rows > 1) {
			if ($end_row) {
				if (!$shortslot) {
					if ($specialdebug) {
						writeDebug("DisplayListings::no room to display record(A)");
					}
					$colpos = 1;
					$shortslot = 0;
					$end_row = 1;
					$total_minutes = 0;
					if ($specialdebug) {
						writeDebug("DisplayListings::bailing early(A)");
					}
					if ($specialdebug) {
							writeDebug("DisplayListings::(exiting)(A)");
					}
					return 1;
				}
			}
		}
	}


	$reset_flag = 1;


	if ($end_row) {
		if ($clean_up) {
			if ($specialdebug) {
				writeDebug("DisplayListings::cleanup on aisle 7 - reset: $reset_flag");
			}
			$rows++;
			$hdr_ctr++;
			print "</tr>\n";
			$shortslot = 0;	
			$debug_state = 0;
			$clean_up = 0;

			#-------------------------------------------------------------------
			# PVB: I needed to add this so that a schedulebar after a very long show
			# (starts before starttime, ends after endtime)
			# gets displayed properly
			# Question: does this mess up any other column reset logic???
			# Answer: YES, if first show of next row is not at column 1
			#-------------------------------------------------------------------

			#	$colpos = 1; # Reset column position since we are starting a new row


			if ($specialdebug) {
				writeDebug("DisplayListings::cleanup with colpos = $colpos");
			}
			if( $colpos >= $maxpos ) {
				$colpos = 1;
			}

			#--------------------------------------------------------------------
			# Special case: can force a heading by setting hdr_ctr = -1	
			#--------------------------------------------------------------------

			if($hdr_ctr == 0) {
				print "$heading\n";
			} elsif ($showheaderrows) {
				if ($hdr_ctr >= $showheaderrows) {
					print "$heading\n";
					$hdr_ctr = 0;
				}
			}

			$force_new_column = 1;
			
			if ($specialdebug) {
				writeDebug("DisplayListings::finished cleaning up ($rows / $hdr_ctr)");
			}

		}


		if($es_program_start > $es_starttime) {
			local($temp_value) = $es_program_start - $es_starttime;
			local($temp_value) = int $temp_value / 60;

			if ($specialdebug) {
				writeDebug("DisplayListings::Data Short by $temp_value minutes");
			}

			if ($temp_value < $inp_showslots) {	
	
				#--------------------------------------------------------------------
				# Should be alright
				#--------------------------------------------------------------------
				if ($specialdebug) {
					writeDebug("DisplayListings::no padding because $temp_value < $inp_showslots");
				}
			}else{
			    if ($colpos < $maxpos) {
				$colspan = sprintf("%.0f",$temp_value / $inp_showslots);		# round
				#--------------------------------------------------------------------
                                # If we fall short of the end, leave one slot for what must come after
				#--------------------------------------------------------------------
                                if( ($colspan > 1) && ($temp_value > ($colspan-1)*$inp_showslots) && ($temp_value < ($colspan*$inp_showslots)) ) {
					if ($specialdebug) {
						writeDebug("DisplayListings::Leaving one slot open at the end for the next show because pad is $temp_value minutes and display is $colspan * $inp_showslots wide");
					}
                                        $colspan--;
                                }


				if ($specialdebug) {
					writeDebug("DisplayListings::Filling with $colspan columns");
				}
	
				print"\n<tr><td align=center bgcolor=\"$color_channelbackground\">";
				$td_ctr = 0;

				if ( $displayunitlabel ) {
					print "<font size=2 face=\"$font_channel\" color=\"$color_channeltext\">$displayunitlabel</FONT>\n";
				} else {
					if ($showchannelicons > 0) {
						if (length($icon{$program_channel}) > 0) {
							print "<img src=$icon{$program_channel}><br>";
						}
					}
					print "<font size=2 face=\"$font_channel\" color=\"$color_channeltext\"><B>$program_tuning<br>\n";

					#--------------------------------------------------------------------
					# Add a link to show just the single channel with 2 days of listings
					#--------------------------------------------------------------------

					$url_parms = "";
					addParameter("FIRSTTUNE",$program_tuning);
					addParameter("LASTTUNE",$program_tuning);
					addParameter("SHOWHOURS","48");
					addParameter("SHOWPDAFORMAT",$showpdaformat);

					print "<a href=\"$scriptdir/$scriptname$url_parms\">$program_channel</a></b></font>\n";
				}
	

				print "<td colspan=$colspan align=middle valign=middle bgcolor=$color_show[0]>\n";
				$td_ctr += $colspan;


				#--------------------------------------------------------------------
				# When displaying a bar of scheduled programming, never say "NO DATA"
				#--------------------------------------------------------------------

				if ( !$displayunitlabel ) {
					print "<font size=2><B><I>NO DATA</I></B></FONT>\n";
				}
				$colpos = 1 + $colspan;
				$reset_flag = 0;
				$end_row = 0;
				$total_minutes = 0;
			    }else{
				if (!$shortslot) {
					if ($specialdebug) {
						writeDebug("DisplayListings::no room to display record(B)");
					}
					$colpos = 1;
					$shortslot = 0;
					$end_row = 1;
					$total_minutes = 0;
					if ($specialdebug) {
						writeDebug("DisplayListings::bailing early(B)");
					}
					if ($specialdebug) {
						writeDebug("DisplayListings::(exiting)(B)");
					}
					return 1;
				}
			    }
			}
		}

		$colspan = 0;
		$end_row = 0;
		$total_minutes= 0;
		if ($reset_flag) {
			$colpos = 1;
		}
	}

	#-------------------------------------------------------------------------------
	# Cleanup (if needed) is finished and we're ready to begin working on this
	# slot.
	#-------------------------------------------------------------------------------

	
	$tmp_slotstart = $es_starttime + ((($colpos - 1) * $inp_showslots) * 60);

	if ($tmp_slotstart != $es_slotstart) {
		if ($specialdebug) {
			writeDebug("DisplayListings::selected slot has changed, updating.");
		}
		&CalculateSlotTimes;

		if ($specialdebug) {
			writeDebug("DisplayListings:: Current Slot: " . as_hhmm($es_slotstart) . " $es_slotstart");
			writeDebug("DisplayListings::    Next Slot: " . as_hhmm($es_nextslot) . " $es_nextslot");
			writeDebug("DisplayListings::Previous Slot: " . as_hhmm($es_prevslot) . " $es_prevslot");
		}
	}
	
	if ($specialdebug) {
		writeDebug("DisplayListings::Slot starting at " . as_hhmm($tmp_slotstart));
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::SS: $shortslot TM: $total_minutes CP: $colpos ER: $end_row ST: $starttime PS: $program_start PTS: ($program_true_start)");
	}

	#-------------------------------------------------------------------------------
	# Calculate the number of columns we need to span, the calculation can vary 
	# depending if the show will end cleanly on the next slot or not
	#
	# These checks help 'snap' the show to the grid.
	#
	# NOTE: If $colpos changes, you must run &CalculateSlotTimes again for it to 
        #	process properly later.
	#-------------------------------------------------------------------------------


	if ($total_minutes > $inp_showslots) {
		$tmp_slotstart = $es_slotstart + ($total_minutes * 60);
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::initial checks");
		writeDebug("DisplayListings::check 1 PTS:" . as_hhmm($es_program_true_start) . " PS " . as_hhmm($es_program_start) . " NXS " . as_hhmm($es_nextslot));
	}

	if ($es_program_true_start >= $es_nextslot) {
		if ($specialdebug) {
			writeDebug("DisplayListings::check 1 triggered ($shortslot)");
		}

		if ($shortslot) {
			$force_new_column = 1;
			$colpos++;
			$shortslot = 0;
			$total_minutes = 0;
			&CalculateSlotTimes;

			if ($specialdebug) {
				writeDebug("DisplayListings::check 1: FNC forced to 1, SS canceled, CP incremented to $colpos");
				writeDebug("DisplayListings::Updating...");
				writeDebug("DisplayListings:: Current Slot: " . as_hhmm($es_slotstart) . " $es_slotstart");
				writeDebug("DisplayListings::    Next Slot: " . as_hhmm($es_nextslot) . " $es_nextslot");
				writeDebug("DisplayListings::Previous Slot: " . as_hhmm($es_prevslot) . " $es_prevslot");
			}
		}
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::check 2 PTS:" . as_hhmm($es_program_true_start) . " PS " . as_hhmm($es_program_start) . " NXS " . as_hhmm($es_slotstart));
	}

	if ($es_program_true_start == $es_slotstart) {
		if ($specialdebug) {
			writeDebug("DisplayListings::check 2 triggered ($shortslot)");
		}

		if ($shortslot) {
			$force_new_column = 1;
			$shortslot = 0;
			$total_minutes = 0;
			
			if ($specialdebug) {
				writeDebug("DisplayListings::check 2 confirmed: FNC forced to 1, SS canceled");
			}
		}
	}


	if ($specialdebug) {
		writeDebug("DisplayListings::check 3 PTS:" . as_hhmm($es_program_true_start) . " PS " . as_hhmm($es_program_start) . " NXS " . as_hhmm($es_prevslot));
	}

	if ($es_program_true_start == $es_prevslot) {
		if ($specialdebug) {
			writeDebug("DisplayListings::check 3 triggered ($shortslot)");
		}
		if ($shortslot) {
			$force_new_column = 1;
			$colpos--;
			$shortslot = 0;
			$total_minutes = 0;
			&CalculateSlotTimes;
			
			if ($specialdebug) {
				writeDebug("DisplayListings::check 3 confirmed: FNC forced to 1, SS canceled, CP decremented to $colpos");
				writeDebug("DisplayListings::Updating...");
				writeDebug("DisplayListings:: Current Slot: " . as_hhmm($es_slotstart) . " $es_slotstart");
				writeDebug("DisplayListings::    Next Slot: " . as_hhmm($es_nextslot) . " $es_nextslot");
				writeDebug("DisplayListings::Previous Slot: " . as_hhmm($es_prevslot) . " $es_prevslot");
			}
		}
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::initial checks completed");
	}

	#--------------------------------------------------------------------------------
	# Check slot alignments
	#--------------------------------------------------------------------------------


	if ($specialdebug) {
		writeDebug("DisplayListings::checking for shows that need aligned");
	}

	if (($es_program_true_start != $es_slotstart) && ($program_stop != $endtime)) {
			
		if ($specialdebug) {
			writeDebug("DisplayListings::start alignment processing");
		}

		$length_offset = $es_slotstart - $es_program_true_start;
		$length_offset = int $length_offset / 60;
		if ($length_offset < 1) {
			$length_offset = 0;
		}
			
		$temp_value = $display_length - $length_offset;

		if ($specialdebug) {
			writeDebug("DisplayListings::SLOT: $es_slotstart TV: $temp_value NSLOT: " . $es_nextslot);
			writeDebug("DisplayListings::SLOT: " . as_hhmm($es_slotstart) . " TV: $temp_value NSLOT: " . as_hhmm($es_nextslot) . " / " . as_hhmm($es_slotstart + (($temp_value + $total_minutes) * 60)));
		}


		if (($es_slotstart + (($temp_value + $total_minutes) * 60)) == $es_nextslot) {
			$shortslot = 0;
			$total_minutes = 0;
			if ($specialdebug) {
				writeDebug("DisplayListings::SS: $shortslot (cancelled) TM: $total_minutes - ends perfectly on the next slot");
			}
		}

		#-----------------------------------------------------------------
		# Experimental ***
		#-----------------------------------------------------------------

		if ($total_minutes > 0) {
			if ($specialdebug) {
				writeDebug("DisplayListings::TV: $temp_value, TM: $total_minutes, SS: $shortslot");
			}
		
			$temp_value = $temp_value + $total_minutes;

			if ($specialdebug) {
				writeDebug("DisplayListings::Adjusted TV to $temp_value");
			}
		
		}

		#-----------------------------------------------------------------
		# Experimental End **
		#-----------------------------------------------------------------


		$colspan = sprintf("%.0f",$temp_value / $inp_showslots);		# round

		if ($colspan < 1) {
			$colspan = 1;
			if ($specialdebug) {
				writeDebug("DisplayListings::CS: Column not visible, correcting");
			}
		}

		if ($specialdebug) {
			writeDebug("DisplayListings::CS: $colspan ($es_program_true_start!=$es_starttime)");
		}
		if ($specialdebug) {
			writeDebug("DisplayListings::TV: $temp_value, LO: $length_offset, DL: $display_length");
		}
			
		# $colspan = int $temp_value / $inp_showslots;

		if ($specialdebug) {
			writeDebug("DisplayListings::alignment processing complete");
		}

	}else{
		if ($specialdebug) {
			writeDebug("DisplayListings::show already aligned");
		}

		$colspan = sprintf("%.0f",$program_length / $inp_showslots);		# round
		# $colspan = int $program_length / $inp_showslots;
		if ($colspan < 1) {
			$colspan = 1;
			if ($specialdebug) {
				writeDebug("DisplayListings::Column not visible, correcting");
			}
		}

		if ($specialdebug) {
			writeDebug("DisplayListings::CS: $colspan ($es_program_true_start==$es_starttime)");
		}
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::alignment checks complete");
	}


	#-------------------------------------------------------------------
	# If the endtime is LESS than the next slot's time, decrement the
	# colspan.  
	#-------------------------------------------------------------------


	if ($specialdebug) {
		writeDebug("DisplayListings::checking column span");
	}
	
	$tmp_slotend = ($es_starttime + (((($colpos + $colspan) -1) * $inp_showslots) * 60));
	$tmp_nextslot = ($es_starttime + ((($colpos + $colspan) * $inp_showslots) * 60));		

	if ($es_program_stop < $tmp_slotend) {
		if ($shortslot) {
			#--------------------------------------------------------------------
			# Do not modify colspan
			#--------------------------------------------------------------------

		}else{
			
			if (($tmp_slotend - $es_program_stop) < $grid_leeway_second) {
				if ($specialdebug) {
					writeDebug("DisplayListings::Leeway check " . ($tmp_slotend - $es_program_stop) . " < $grid_leeway_second");
					writeDebug("DisplayListings::CS left at $colspan (" . as_hhmm($es_program_stop) . " < " . as_hhmm($tmp_slotend) . " [" . as_hhmm($tmp_nextslot) . "]) (1) - within $grid_leeway_second seconds");
				}
			}else{
				$colspan--;
				if ($specialdebug) {
					writeDebug("DisplayListings::CS adjusted to $colspan (" . as_hhmm($es_program_stop) . " < " . as_hhmm($tmp_slotend) . " [" . as_hhmm($tmp_nextslot) . "]) (1)");
				}
			}
		}
	}

	#-------------------------------------------------------------------
	# If the endtime of the program IS the next slot, go for it.
	#-------------------------------------------------------------------


	if ($es_program_stop == $tmp_nextslot) {
		if ($shortslot) {
			#--------------------------------------------------------------------
			# Do not modify colspan
			#--------------------------------------------------------------------

		}else{
			$colspan++;
			if ($specialdebug) {
				writeDebug("DisplayListings::CS adjusted to $colspan (" . as_hhmm($es_program_stop) . " == " . as_hhmm($tmp_nextslot) . ") (2)");
			}
		}
	}


	#--------------------------------------------------------------------
	# Sanity Check colspan
	#--------------------------------------------------------------------

	if ($colspan < 1) {
		$colspan = 1;
				
		if ($specialdebug) {
			writeDebug("DisplayListings::colspan less than 1, readjusting");
		}

	}

	#--------------------------------------------------------------------
	# Flag if the slot is approximate
	#--------------------------------------------------------------------

	if ($colspan > int ($program_length / $inp_showslots)) {
		$slot_approximate = 1;
	}else{
		$slot_approximate = 0;
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::CS: $colspan - is approximate? $slot_approximate");
	}


	#-------------------------------------------------------------------
	# Handle programming less than one slot in length.
	#
	# There is a debug_state variable for tracing this path.
	#-------------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("DisplayListings::entering partial slot processor");
		writeDebug("DisplayListings::SS: $shortslot PD: $previous_display TM: $total_minutes DL: $display_length");
	}

	
	if ($display_length < $inp_showslots) {
		if ($specialdebug) {
			writeDebug("DisplayListings::potential partial slot detected");
		}

		$debug_state = "A1";
		if ($total_minutes <= $inp_showslots) {
			$debug_state = "A1A";
			if (($total_minutes + $display_length) <= $inp_showslots) {
				$debug_state = "A1AA";
				if (!$shortslot) {
					if ($previous_display >= $inp_showslots) {
						$total_minutes = 0;
					}else{
						$total_minutes = $previous_display;
					}
				}
				$shortslot = 1;
				if ($specialdebug) {
					writeDebug("DisplayListings::SS adjusted to $shortslot at $debug_state");
				}
			}else{
				$debug_state = "A1AB";
				if ($specialdebug) {
					writeDebug("DisplayListings::TM adjusted to $total_minutes at $debug_state SS: $shortslot");
				}

				if (($total_minutes + $display_length) < $inp_showslots) {
					$debug_state = "A1ABA";
					if ($shortslot) {
						$colpos = $colpos + 1;
						if ($specialdebug) {
							writeDebug("DisplayListings::CP adjusted to $colpos at $debug_state TM: $total_minutes SS: $shortslot");
						}
					}
					$shortslot = 1;
				}else{
					$debug_state = "A1ABB";
					if (($es_nextslot - $es_program_true_start) >= $grid_leeway_second) {
						$debug_state = "A1ABB1";
						if ($specialdebug) {
							writeDebug("DisplayListings::$debug_state (" . as_hhmm($es_program_true_start) . " > " . as_hhmm($es_nextslot) . " - within $grid_leeway_second seconds)");
						}
					}else{
						$debug_state = "A1ABB2";
						$shortslot = 0;
						# $total_minutes = 0;	
						if ($specialdebug) {
							writeDebug("DisplayListings::SS reset ($shortslot) at $debug_state TM $total_minutes PD $previous_display");
							writeDebug("DisplayListings::" . ($es_nextslot - $es_program_true_start));
						}
					}
				}
			}
		}else{
			$debug_state = "A1B";
			$tmp_nextslot = (as_epoch_seconds($starttime) + ((($colpos) * $inp_showslots) * 60));
			if (($es_nextslot - $es_program_true_start) < $grid_leeway_second) {
				if ($specialdebug) {
					writeDebug("DisplayListings::$debug_state (" . as_hhmm($es_program_true_start) . " < " . as_hhmm($es_nextslot) . " - within $grid_leeway_second seconds)");
				}
				$debug_state = "A1BA";
				if ($shortslot == 1) {
					$debug_state = "A1BA1";
					$colpos = $colpos + 1;
					if ($specialdebug) {
						writeDebug("DisplayListings::CP adjusted to $colpos at $debug_state");
					}
				}
				$shortslot = 1;
				if ($specialdebug) {
					writeDebug("DisplayListings::SS set to $shortslot at $debug_state");
				}
			}else{
				$debug_state = "A1BAB";
				$shortslot = 1;
				if ($specialdebug) {
					writeDebug("DisplayListings::SS set to $shortslot at $debug_state");
				}
			}
		}
	}else{
		$debug_state = "A2";
		if ($total_minutes > 0) {
			$debug_state = "A2A";
			if ($specialdebug) {
				writeDebug("DisplayListings::$debug_state TM $total_minutes");
				writeDebug("DisplayListings::$debug_state SS: $shortslot DL: $display_length CP: $colpos CS: $colspan");
			}
			if (($total_minutes + $display_length) <= $inp_showslots) {
				$debug_state = "A2AA";
				if ($es_program_true_start > $es_slotstart) {
					if ($specialdebug) {
						writeDebug("DisplayListings::PTS " . as_hhmm($es_program_true_start) . " > " . as_hhmm($es_slotstart));
					}	
					$colpos = $colpos + 1;
					local($temp_value) = ($program_length / $inp_showslots);
					if ($specialdebug) {
						writeDebug("DisplayListings::CP adjusted to $colpos at $debug_state ($temp_value)");
					}
				
					if ($colspan > $temp_value) {
						$colspan--;
						if ($specialdebug) {
							writeDebug("DisplayListings::CS adjusted to $colspan at $debug_state");
						}
					}
				}else{
					$debug_state = "A2AA1";
				}
			}
		}

#		$shortslot = 0;	
#		$total_minutes = 0;

		$temp_value3 = 0;
		if ($es_program_stop == $es_nextslot) {			# Was $colpos+1  bug?  that's 2 slots ahead

			$temp_value3 = (($inp_showslots * $colspan) - ($es_program_stop) - $es_program_true_start) / 60;
			local($spanstop) = ($es_starttime + ($inp_showslots * ($colspan+$colpos-1) * 60));
			local($showstop) = $es_program_stop;

			if (($temp_value3 < 0) && ($temp_value3 > -15)) {
				if ($spanstop != $showstop) {
					$debug_state = "A3AAA";
					$colspan++;
					if ($specialdebug) {
						writeDebug("DisplayListings::CS adjusted to $colspan at $debug_state (" . as_hhmm($spanstop) . " != " . as_hhmm($showstop) . ") TV3: $temp_value3");
					}
				}else{
					$debug_state = "A3AAB";
				}
			}else{
				$debug_state = "A3AB";
			}
		}else{
			$debug_state = "A3B";
		}

		if ($specialdebug) {
			writeDebug("DisplayListings::$debug_state CS: $colspan");
		}

	}


	if ($shortslot) {
		$debug_state = "B";			
		if ($specialdebug) {
			writeDebug("DisplayListings::$debug_state final check");
		}
		if ($max_span) {
			$debug_state = "B1";
			if ($specialdebug) {
				writeDebug("DisplayListings::$debug_state $max_span > 0");
			}
			if ($colspan > $max_span) {
				$debug_state = "B1A";
				if ($specialdebug) {
					writeDebug("DisplayListings::$debug_state $max_span > $colspan");
				}

				$colspan = $colspan - $max_span;
				$colpos = $colpos + $max_span;
					
			
				&CalculateSlotTimes;


				$shortslot = 0;
			
				if ($specialdebug) {
					writeDebug("DisplayListings::$debug_state SS canceled CP: $colpos CS: $colspan ER: $end_row MP: $maxpos");
					writeDebug("DisplayListings::Updating...");
					writeDebug("DisplayListings:: Current Slot: " . as_hhmm($es_slotstart) . " $es_slotstart");
					writeDebug("DisplayListings::    Next Slot: " . as_hhmm($es_nextslot) . " $es_nextslot");
					writeDebug("DisplayListings::Previous Slot: " . as_hhmm($es_prevslot) . " $es_prevslot");
				}
			}
		}else{
			$debug_state = "B2";

			if ($specialdebug) {
				writeDebug("DisplayListings::$debug_state $max_span is zero or undefined");
			}

			if ($specialdebug) {
				writeDebug("DisplayListings::program ends at " . as_hhmm($es_program_stop) . " next slot starts at " . as_hhmm($es_nextslot));
			}

			if ($es_program_stop >= $es_nextslot) {
				$debug_state = "B2A";
				if ($es_program_true_start == $es_slotstart) {
					$debug_state = "B1A1";
					$shortslot = 0;
			
					if ($specialdebug) {
						writeDebug("DisplayListings::$debug_state SS canceled CP: $colpos CS: $colspan ER: $end_row MP: $maxpos");
					}
				}
			}

	
			if ($specialdebug) {
				writeDebug("DisplayListings::$debug_state final complete (SS: $shortslot)");
			}
		}

	}




	if ($specialdebug) {
		writeDebug("DisplayListings::finished partial slot processor (SS: $shortslot)");
	}


	#-------------------------------------------------------------------
	# If it's a short slot we may need to make some adjustments
	#-------------------------------------------------------------------

	if ($shortslot) {
		if ($total_minutes == $display_length) {
			$temp_value2 = $es_endtime - $es_program_true_start;
			$temp_value2 = int ( $temp_value2 / 60 );
			if ($temp_value2 < 0) {
				$temp_value2 = 0;
			}

			if (($temp_value2 < $inp_showslots) && ($colpos > $maxpos)) {
				$shortslot = 0;
				$total_minutes = 0;
				if ($specialdebug) {
					writeDebug("DisplayListings::shortslot cancelled");
					writeDebug("DisplayListings::TV2: $temp_value2 CP: $colpos MP: $maxpos ISS: $inp_showslots");
				}
			}


		}
	}

	#-------------------------------------------------------------------
	# If it's a regular slot check ranges.
	#
	# This could be part of the previous if as an else but there may
	# be times when you want to comment one out and not the other.
	# (For testing or an alternate application.)
	#
	#-------------------------------------------------------------------

	if (!$shortslot) {
		if (($colpos + $colspan) > $maxpos) {
			if ($specialdebug) {
				writeDebug("DisplayListings::span would cross edge, ending at edge and flagging end_row CS: $colspan TD: $td_ctr");
			}
			$colspan = ($maxpos+1) - $colpos;
			$end_row = 1;
			if ($specialdebug) {
				writeDebug("DisplayListings::CP: $colpos MP: $maxpos CS: $colspan MS: $max_span SS: $shortslot ER: $end_row TD: $td_ctr");
			}
		}

		if (($colspan > $maxpos) || ($es_program_stop >= $es_endtime)) {
			if ($specialdebug) {
				writeDebug("DisplayListings::span is past edge, ending at edge and flagging end_row CS: $colspan TD: $td_ctr");
			}
			$colspan = ($maxpos+1) - $colpos;
			$end_row = 1;

			if ($specialdebug) {
				writeDebug("DisplayListings::CP: $colpos MP: $maxpos CS: $colspan MS: $max_span SS: $shortslot ER: $end_row TD: $td_ctr");
			}

		}

		#--------------------------------------------------------------------------------
		# Due to limitations by doing this one row at a time, sometimes the grid is a
		# little bit off and we end up wanting to do an extra column.   To keep the 
		# display nice we just chop it off early.
		#
		# This won't occur very often.
		#--------------------------------------------------------------------------------


		if ((($colpos == $maxpos) && ($td_ctr == $maxpos)) ) {
			if ($specialdebug) {
				writeDebug("DisplayListings::start is off edge, supressing display and flagging end_row CS: $colspan TD: $td_ctr FNC: $force_new_column");
			}
			$colspan = 0;
			$end_row = 1;

			if ($specialdebug) {
				writeDebug("DisplayListings::CP: $colpos MP: $maxpos CS: $colspan MS: $max_span SS: $shortslot ER: $end_row TD: $td_ctr  FNC: $force_new_column");
			}

		}
	}


	if (($total_minutes == 0) && ($shortslot)) {

		if ($specialdebug) {
			writeDebug("DisplayListings::check 2 PTS:" . as_hhmm(as_epoch_seconds($program_true_start)) . " PS " . as_hhmm($es_program_start) . " NXS " . as_hhmm(as_epoch_seconds($starttime) + ((($colpos-1) * $inp_showslots) * 60)));
		}

		if ($es_program_true_start > $es_slotstart -1) {
			if ($shortslot) {
				$force_new_column = 1;
			
				if ($specialdebug) {
					writeDebug("DisplayListings::forcing new column (TM is $total_minutes and SS $shortslot)");
				}
			}
		}
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::CP: $colpos CS: $colspan SS: $shortslot DS: $debug_state MP $maxpos TM: $total_minutes DL: $display_length MS: $max_span TD: $td_ctr");
	}


	#-------------------------------------------------------------------
	# If colSpan is non-zero then we have something to display
	#-------------------------------------------------------------------

	if ($colspan > 0) {
	        #-------------------------------------------------------------------
	        # Display channel or replay unit names in the left column
	        #-------------------------------------------------------------------
		if ($colpos == 1) {
			if ($shortslot) {
				if ($new_row){
					if ($specialdebug) {
						writeDebug("DisplayListings::starting row, NR: $new_row / FNC: $force_new_column");
					}
					print"\n<tr><td align=center bgcolor=\"$color_channelbackground\">";
					$td_ctr = 0;

					if ( $displayunitlabel ) {
						print "<font size=2 face=\"$font_channel\" color=\"$color_channeltext\">$displayunitlabel</FONT>\n";
					} else {
						if ($showchannelicons > 0) {
							if (length($icon{$program_channel}) > 0) {
								print "<img src=$icon{$program_channel}><br>";
							}
						}
						print "<font size=2 face=\"$font_channel\" color=\"$color_channeltext\"><B>$program_tuning<br>\n";
						#--------------------------------------------------------------------
						# Add a link to show just the single channel with 2 days of listings
						#--------------------------------------------------------------------

						$url_parms = "";
						addParameter("FIRSTTUNE",$program_tuning);
						addParameter("LASTTUNE",$program_tuning);
						addParameter("SHOWHOURS","48");
						addParameter("SHOWPDAFORMAT",$showpdaformat);

						print "<a href=\"$scriptdir/$scriptname$url_parms\">$program_channel</a></b></font>\n";
						
					}
					$new_row = 0;
					$force_new_column = 1;
					if ($specialdebug) {
						writeDebug("DisplayListings::row started, NR: $new_row / FNC: $force_new_column");
					}

				}
			}else{
				if (($dl_lasttuning == $program_tuning) && ($previous_display > 0)) {
					if ($specialdebug) {
						writeDebug("DisplayListings::using same row ($dl_lasttuning, $program_tuning, $previous_display, $new_row)");
					}
				}else{
					if ($specialdebug) {
						writeDebug("DisplayListings::starting row ($dl_lasttuning, $program_tuning, $new_row)");
					}
					print"\n<tr><td align=center bgcolor=\"$color_channelbackground\">";
					$td_ctr = 0;

					if ( $displayunitlabel ) {
						print "<font size=2 face=\"$font_channel\" color=\"$color_channeltext\">$displayunitlabel</FONT>\n";
					} else {
						if ($showchannelicons > 0) {
							if (length($icon{$program_channel}) > 0) {
								print "<img src=$icon{$program_channel}><br>";
							}
						}

						print "<font size=2 face=\"$font_channel\" color=\"$color_channeltext\"><B>$program_tuning<br>\n";
						#--------------------------------------------------------------------
						# Add a link to show just the single channel with 2 days of listings
						#--------------------------------------------------------------------

						$url_parms = "";
						addParameter("FIRSTTUNE",$program_tuning);
						addParameter("LASTTUNE",$program_tuning);
						addParameter("SHOWHOURS","48");
						addParameter("SHOWPDAFORMAT",$showpdaformat);

						print "<a href=\"$scriptdir/$scriptname$url_parms\">$program_channel</a></b></font>\n";
					}
					$new_row = 0;
					$force_new_column = 1;
					if ($specialdebug) {
						writeDebug("DisplayListings::row started, NR: $new_row / FNC: $force_new_column");
					}
				}

			}
		}

		#-------------------------------------------------------------------
		# Render the show data
		#-------------------------------------------------------------------
		if ($specialdebug) {
			writeDebug("DisplayListings::dispatching render");
		}
		&RenderShow;
		if ($specialdebug) {
			writeDebug("DisplayListings::render complete");
		}

		
		#-------------------------------------------------------------------
		# How many minutes were displayed?
		#-------------------------------------------------------------------


		$tmp_slotstart = $es_starttime + ((($colpos - 1) * $inp_showslots) * 60);
		$temp_value = $tmp_slotstart - $es_program_true_start;
		$temp_value = int $temp_value / 60;
		if ($temp_value < 1) {
			$temp_value = 0;
		}
		$temp_value = $display_length - $temp_value;
		if ($temp_value < 0) {
			$temp_value = 0;
		}
		$previous_display = $temp_value;		


		
		if ($es_program_stop >= $es_endtime) {
			$shortslot = 0;
			$end_row = 1;

			if ($specialdebug) {
				writeDebug("DisplayListings::$es_program_stop >= $es_endtime.  ER: $end_row flagged true");
			}

		}

		#-------------------------------------------------------------------
		# Update Column Position (colpos)
		#-------------------------------------------------------------------

		if ($shortslot == 1) {	
			if ($specialdebug) {
				writeDebug("DisplayListings::CP: $colpos TM: $total_minutes ISS: $inp_showslots");
			}
			if ($total_minutes == $inp_showslots) {
				$total_minutes = 0;
				$colpos = $colpos + 1;
			}
		}else{
			if ($specialdebug) {
				writeDebug("DisplayListings::CP: $colpos + CS: $colspan");
			}
	
			$colpos = $colpos + $colspan;

			if ($specialdebug) {
				writeDebug("DisplayListings::CP: $colpos");
			}
		}

		if ($colpos > $maxpos) {
			$end_row = 1;
		}
	}


	#-------------------------------------------------------------------
	# If at the end of the row, reset
	#-------------------------------------------------------------------

	if ($end_row) {
		if ($specialdebug) {
			writeDebug("DisplayListings::ending row ($rows / $hdr_ctr)");
		}

		if(($colpos > 1) && ($colpos <= $maxpos)) {
			$colspan = $maxpos - $colpos + 1;
			print "<td colspan=$colspan align=left valign=top bgcolor=$color_show[0]></td>\n";
			$colpos += $colspan;
			$td_ctr += $colspan;

		}
		$shortslot = 0;	
		$debug_state = 0;
		$previous_display = 0;
		#$end_row = 0;
		$total_minutes = 0;
		$new_row = 1;
	}

	if ( $displayunitlabel ) {
		$dl_lasttuning = $displayunitlabel;
	} else {
		$dl_lasttuning = $program_tuning;
	}

	if ($specialdebug) {
		writeDebug("DisplayListings::(exiting)");
	}

	return 1;
}

#-------------------------------------------------------------------------------------------
sub RenderShow {
	#
	# Render Show Data
	#------------------------------------------------------------------------------------

	my $specialdebug = 0;

	if ($specialdebug) {
		writeDebug("rendershow::starting render for $program_title ($program_id)");
		writeDebug("rendershow::$es_starttime");
	}

	#-------------------------------------------------------------------
	# If RTV mode, check to see if this program is scheduled
	#-------------------------------------------------------------------
	#-------------------------------------------------------------------
	# Color Code the Column 
	#-------------------------------------------------------------------
		
        if (as_epoch_seconds($program_stop) < as_epoch_seconds($now_timestring))  {
		#-------------
                # Past show
		#-------------
		$program_timing = 0;
        }elsif ($es_program_start < as_epoch_seconds($now_timestring))  {
		#-------------
                # Current show
		#-------------
		$program_timing = 1;
        } else {
		#-------------
                # Future show
		#-------------
		$program_timing = 2;
	}
	$bgcolor = $color_show[$program_timing];

	if($rtvaccess) {
		$program_icon = getScheduleDetails($program_id,$program_timing);
	}

	if (length($bgcolor) > 0) {
		$bgcolor = " bgcolor=\"$bgcolor\"";
	}

	
	#-------------------------------------------------------------------
	# If it's a short slot, determine if we need a secondary row or not
	#-------------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("rendershow::SS: $shortslot TM: $total_minutes DL: $display_length CS: $colspan CP: $colpos MP: $maxpos ER: $end_row TD: $td_ctr");
	}

	if ($shortslot) {
		if (($new_row) || ($force_new_column)){
			if ($specialdebug) {
				writeDebug("rendershow::starting new column, SS: $shortslot FNC: $force_new_column NR: $new_row");
			}

			if ($td_ctr >= $maxpos) {
				if ($specialdebug) {
					writeDebug("rendershow::canceling new column start since $td_ctr >= $maxpos");
				}
				return 0;
			}

			print "<td colspan=$colspan align=left valign=top $bgcolor>";
			$td_ctr += $colspan;

			$new_row = 0;
			$force_new_column = 0;
			$tmp_offset = (($es_starttime + ((($colpos - 1) * $inp_showslots) * 60)) - ($es_program_true_start)) / 60;
			$total_minutes = $display_length;
			if ($tmp_offset > 0) {
				$total_minutes = $total_minutes + $tmp_offset;
			}
			$max_span = $colspan;
			if ($specialdebug) {
				writeDebug("rendershow::TO: $tmp_offset TM: $total_minutes DL: $display_length MS: $max_span CS: $colspan");
			}
		}else{
			print "<hr>\n";
			$total_minutes = $total_minutes + $display_length;
			if ($specialdebug) {
				writeDebug("rendershow::continuing column, SS: $shortslot TM: $total_minutes DL: $display_length");

			}
		
			#----------------------------------------------------------------
			# If the continuing the column is a *late* decision, backtrack 
			# the column position.
			#----------------------------------------------------------------

			if (!$tmp_shortslot) {
				$colpos = $colpos - $tmp_colspan;
				if ($colpos < 1) {
					$colpos = 1;
				}
				if ($specialdebug) {
					writeDebug("rendershow::adjusting colpos to $colpos");

				}				
			}
			
			

		}
	}else{
		print "<td colspan=$colspan align=left valign=top $bgcolor>";
		$td_ctr += $colspan;

		if ($specialdebug) {
			writeDebug("rendershow::starting new column");
		}
		$force_new_column = 0;
		$max_span = $colspan;
		if ($display_length < $inp_showslots) {
			$total_minutes = $display_length;
			$shortslot = 1;
			if ($specialdebug) {
				writeDebug("rendershow::show is smaller than slot, SS: $shortslot TM: $total_minutes DL: $display_length");
			}

		}else{
			$max_span = 0;
		}

	}

	#-------------------------------------------------------------------
	# Display Data
	#-------------------------------------------------------------------
	print "\n<font size=2>";
	#--------------------------------------------------------------------
	# When showing the schedule bar, prefix the show with the channel number
	#--------------------------------------------------------------------
	if ( $displayunitlabel && $program_tuning ) {
		print "$program_tuning: ";
	} else {
		if ($es_program_true_start != ($es_starttime + ((($colpos - 1) * $inp_showslots) * 60)) ) {
			if ($specialdebug) {
				writeDebug("rendershow::" . as_hhmm($es_program_true_start) . "!=" . as_hhmm($es_starttime + ((($colpos - 1) * $inp_showslots) * 60)) );
			}
			print "(" . as_hhmm($es_program_true_start) . ")<br>";
#--------------------------------------------------------------------------------
# This is useful for debugging
#
#			print "($colpos " . as_hhmm($es_starttime + ($inp_showslots * ($colpos * 60))) . ")<br>";
#--------------------------------------------------------------------------------

		}
	}
	if ($debug) {
		print "(S: " . as_hhmm($es_program_start) . ")<br>";
		print "(E: " . as_hhmm($es_program_stop) . ")<br>";
		print "(V: CP)$colpos,CS)$colspan,PL)$program_length,LO)$length_offset,TV)$temp_value,TV2)$temp_value2,TV3)$temp_value3,SS)$shortslot,DS)$debug_state)<br>";
	}

	print "<a ";
	if ($create_anchor) {
		print "name=\"$program_id\" ";
	}

	$url_parms = "";
	addParameter("PROGRAMID",$program_id);
	addParameter("STARTDATE",$inp_startdate);
	addParameter("STARTHOUR",$inp_starthour);
	addParameter("SHOWHOURS",$inp_showhours);
	addParameter("SHOWSLOTS",$inp_showslots);
	addParameter("SHOWPDAFORMAT",$showpdaformat);

	print "href=\"$scriptdir/$scriptname$url_parms\"";
	
	if ($newwindow) {
		print " target=\"_blank\"";
	}
	print ">";
	print renderhtml($program_title) . "</B>";

	if ($program_movieyear) {
		print " <small>" . substr($stars,1,$program_stars);
		print " ($program_movieyear, $program_category)</small>";
	}
	print "</a>\n";

	print "</font>\n";

	#---------------------------------------------------------------------
	# If showschedulebar == 2, skip the details to keep things brief
	#---------------------------------------------------------------------

	if( ! ($displayunitlabel && ($showschedulebar == 2))) {
		print "<br>\n";
		if (length($program_subtitle) > 0) {
			print "<font size=-1>\"". renderhtml($program_subtitle) . "\"</font><br>\n";
		}
		print "<font size=-2>";

		if (length($program_episodenum) > 0) {
			print "$program_episodenum. \n";
		}

		if ((length($program_category) > 0) && ($program_movieyear == 0)) {
			print "($program_category)\n";
		}

		if (length($program_desc) > 0) {
			if (length($program_category) > 0) {
				print " ";
			}
			print renderhtml($program_desc);
		}

		if (length($program_advisories) > 0) {
			if (length($program_desc) > 0) {
				print " ";
			}
				
			print "(" . renderhtml($program_advisories) . ")";
		}

		print " $display_length minutes";
		if ($fudged_length) {
			print "(approx)";
		}
		print ".\n";
		if (length($program_mpaarating) > 0)  {
			$temp_display = "$program_mpaarating.";
			if ($showchannelicons > 0) {
				if (($program_mpaarating eq "G") && (length($image_mpaag))) {
					$temp_display = buildImage($image_mpaag,$imagedir,$program_mpaarating);
				}
				if (($program_mpaarating eq "PG") && (length($image_mpaapg))) {
					$temp_display = buildImage($image_mpaapg,$imagedir,$program_mpaarating);
				}
				if (($program_mpaarating eq "PG-13") && (length($image_mpaapg13))) {
					$temp_display = buildImage($image_mpaapg13,$imagedir,$program_mpaarating);
				}
				if (($program_mpaarating eq "R") && (length($image_mpaar))) {
					$temp_display = buildImage($image_mpaar,$imagedir,$program_mpaarating);
				}
				if (($program_mpaarating eq "NC17") && (length($image_mpaanc17))) {
					$temp_display = buildImage($image_mpaanc17,$imagedir,$program_mpaarating);
				}
	
			}
			print " $temp_display\n";
		}else{ 
			if ($program_movieyear) {
				$temp_display = "NR.";
				if ($showchannelicons > 0) {
					if (length($image_mpaanr)) {
						$temp_display = buildImage($image_mpaanr,$imagedir,"NR");
					}	
				}
				print " $temp_display\n";
	
			}
		}
	
		if (length($program_vchiprating) > 0)  {
			$temp_display = "TV-$program_vchiprating.";
			if ($showchannelicons > 0) {
				if (($program_vchiprating eq "G") && (length($image_tvg))) {
					$temp_display = buildImage($image_tvg,$imagedir,"TV-$program_vchiprating");
				}
				if (($program_vchiprating eq "PG") && (length($image_tvpg))) {
					$temp_display = buildImage($image_tvpg,$imagedir,"TV-$program_vchiprating");
				}
				if (($program_vchiprating eq "14") && (length($image_tv14))) {
					$temp_display = buildImage($image_tv14,$imagedir,"TV-$program_vchiprating");
				}
				if (($program_vchiprating eq "MA") && (length($image_tvma))) {
					$temp_display = buildImage($image_tvma,$imagedir,"TV-$program_vchiprating");
				}
				if (($program_vchiprating eq "Y") && (length($image_tvy))) {
					$temp_display = buildImage($image_tvy,$imagedir,"TV-$program_vchiprating");
				}
				if (($program_vchiprating eq "Y7") && (length($image_tvy7))) {
					$temp_display = buildImage($image_tvy7,$imagedir,"TV-$program_vchiprating");
				}
			}
			print " $temp_display\n";
		}

		if (length($program_captions) > 0)  {
			$temp_display = "CC";
			if ($showchannelicons > 0) {
				if (length($image_cc) > 0) {
					$temp_display = buildImage($image_cc,$imagedir,"CC");
				}
			}
			print " $temp_display\n";
		}

		if ($program_stereo) {
			$temp_display = "Stereo.";
			if ($showchannelicons > 0) {
				if (length($image_stereo) > 0) {
					$temp_display = buildImage($image_stereo,$imagedir,"Stereo");
				}
			}
			print " $temp_display\n";
		}
	
		if ($program_repeat) {
			$temp_display = "(Repeat)";
			if ($showchannelicons > 0) {
				if (length($image_repeat) > 0) {
					$temp_display = buildImage($image_repeat,$imagedir,"Repeat");
				}
			}
			print " $temp_display\n";
		}


		if (length($program_extra) > 0) {
			print "<br>\n$program_extra\n";
		}
		

		if ($slot_approximate) {
#--------------------------------------------------------------------------------
#			print "****";
#--------------------------------------------------------------------------------
		}

		if (length($program_icon) > 0) {
			print "\n<br>$program_icon";
		}
	
		print "</font>\n";
	}

	if ($specialdebug) {
		writeDebug("rendershow::CS: $colspan MS: $max_span CP: $colpos TM: $total_minutes DL: $display_length SS: $shortslot TD: $td_ctr");
	}

	if ($specialdebug) {
		writeDebug("rendershow::render complete");
	}

	return 1;
}

#-------------------------------------------------------------------------------------------
sub DisplayToolbox{
	#
	# Display Toolbox
	#
	#-------------------------------------------------------------------------------

	print "<center><font face=\"$font_menu\">";

	#-------------------------------------------------------------------
	# First Toolbox Row
	#-------------------------------------------------------------------

	print "<table><tr>";

	print "<td width=%5 valign=top>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=\"STARTDATE\" value=\"$now_startdate\">\n";
	print "<input type=hidden name=\"STARTHOUR\" value=\"$now_starthour\">\n";
	print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
	print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";

	if (length($icon_now) > 0) {
		print "<input type=image src=\"$imagedir/$icon_now\" ALT=\"Now\">\n";
	}else{
		print "<input type=submit value=\"NOW\" name=\"SUBMIT2\">\n";
	}

	print "</form>\n\n";

	print "<td width=%5 valign=top>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=\"STARTDATE\" value=\"$now_startdate\">\n";
	print "<input type=hidden name=\"STARTHOUR\" value=\"$primetime_start\">\n";
	print "<input type=hidden name=\"SHOWHOURS\" value=\"$defaultshowhours\">\n";
	print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
	if (length($icon_tonight) > 0) {
		print "<input type=image src=\"$imagedir/$icon_tonight\" ALT=\"Prime\">\n";
	}else{
		print "<input type=submit value=\"Prime\" name=\"SUBMIT4\">\n";
	}
	print "</form>\n\n ";

	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<td valign=top>Date: <td valign=top><select size=\"1\" name=\"STARTDATE\">\n";

	do {
		$rng_string = substr(as_time_string($rng_start),0,8);
		$wday = strftime( "%A", localtime($rng_start));
		$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2) . "/" . substr($rng_string,0,4);
		print "<option value=\"$rng_string\"";
		if ($rng_string eq substr($starttime,0,4) . substr($starttime,4,2) . substr($starttime,6,2)) {
			print " selected";
		}
		print ">$dsp_string</option>\n";

		$rng_start = $rng_start + 86400;
		$ctr++;

	} while ($rng_start < $rng_end);
	print "</select>\n";

	print "<td valign=top>Time: <td valign=top>";
	print "<select size=\"1\" name=\"STARTHOUR\">\n";

	$ctr = 0;
	do {
		$dsp_string = as_ampm($ctr);
		print "<option value=\"$ctr\"";
		if ($ctr == int substr($starttime,8,2)) {
			print " selected";
		}
		print ">$dsp_string</option>\n";
		$ctr++;

	} while ($ctr < 24);
	print "</select>\n";

	print "<td valign=top>Hours to Display: <td valign=top>";
	print "<select size=\"1\" name=\"SHOWHOURS\">\n";
	for $hours (2,3,4,5,6,7,8,9,12,24,48,72,96) {
		print "<option value=\"$hours\"";
		if ($inp_showhours == $hours) {
			print " selected";
		}
		print ">$hours Hours</option>\n";
	}
	print "<td valign=top>";

	if (length($icon_go) > 0) {
		print "<input type=image src=\"$imagedir/$icon_go\" ALT=\"Go\">\n";
	}else{
		print "<input type=submit value=\"Go\" name=\"SUBMITGO\">";
	}

	print "</tr></table>\n";

	#-------------------------------------------------------------------
	# Second Row
	#-------------------------------------------------------------------

	print "<table border=0><tr>\n";

	if( defined %favorites ) {
		print "<td valign=top>Channels:\n";
		print "<select name=\"FAVORITE\">\n";
		print "<option value=0";
		if( !$inp_favorite ) {
			print " selected";
		}
		print ">Selected range --&gt;</option>\n";
		foreach $key (keys %favorites) {
			print "<option";
			if($key eq $inp_favorite) {
				print " selected";
			}
			print ">$key</option>\n";
		}
		print "</select>\n";
	}
			
	print "<td valign=top>From: <td valign=top>";
	print "<select size=\"1\" name=\"FIRSTTUNE\">\n";
	$records = 0;
	do {
		$records++;
		if (length($tuning[$records]) > 0) {
			print "<option value=\"$tuning[$records]\"";
			if ($tuning[$records] == $inp_firsttune) {
				print " selected";
			}
			print ">$channel[$records]</option>\n";
		}
	} while ($records < $last_channel+1);

	print "<td valign=top>To: <td valign=top>";
	print "<select size=\"1\" name=\"LASTTUNE\">\n";
	$records = 0;
	do {
		$records++;
		if (length($tuning[$records]) > 0) {
			print "<option value=\"$tuning[$records]\"";
			if ($tuning[$records] == $inp_lasttune) {
				print " selected";
			}
			print ">$channel[$records]</option>\n";
		}
	} while ($records < $channelcount);

	print "<td valign=top>";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "</form>\n";

	print "<td width=\"5%\" valign=top>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
	print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
	print "<input type=hidden name=\"SHOWHOURS\" value=\"$defaultshowhours\">\n";
	print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
	print "<input type=hidden name=\"FIRSTTUNE\" value=\"$first_channel\">\n";
	print "<input type=hidden name=\"LASTTUNE\" value=\"$last_channel\">\n";

	if (length($icon_all) > 0) {
		print "<input type=image src=\"$imagedir/$icon_all\" ALT=\"All\">\n";
	}else{
		print "<input type=submit value=\"ALL\" name=\"SUBMIT3\">";
	}

	print "</form>\n";

	print "<td width=\"5%\">";
	
	$form_end = $tuning[$first_rec + $display_rec];
	if (length($form_end) < 1) { 
		$form_end = $last_channel;
	}

	if ($prevchanok) {
		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$prev_chan\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$form_end\">\n";
	
		if (length($icon_prevchan) > 0) {
			print "<input type=image src=\"$imagedir/$icon_prevchan\" ALT=\"<<<\">\n";
		}else{
			print "<input type=submit value=\"<<<\" name=\"SUBMITPC\">";
		}

		print "</form>\n\n";
	}

	print "<td width=5%>";


	$form_end = $tuning[$last_rec + $display_rec];
	if (length($form_end) < 1) { 
		$form_end = $last_channel;
	}

	if ($nextchanok) {
		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$next_chan\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$form_end\">\n";

		if (length($icon_prevchan) > 0) {
			print "<input type=image src=\"$imagedir/$icon_nextchan\" ALT=\">>>\">\n";
		}else{
			print "<input type=submit value=\">>>\" name=\"SUBMITNC\">";
		}

		print "</form>\n\n";
	}

	my $s_todo = &ToDoSupported;
	my $s_guide = 0;

	if ($rtvaccess) {
		$s_guide = 1;

	}

	if ($rtvaccess) {
		print "<td valign=top>Replay:\n";
		print "<td valign=top><form action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
		print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";
		print "<select size=\"1\" name=\"RTVUNIT\">\n";
		for ( split /,/, $replaylist ) {
			/,/;
			my $addr = $rtvaddress{$_};
			my $label = $rtvlabel{$_};
			print "<option value=$_";
			print ">$label</option>\n";
		}
		print "<option value=0 selected>ALL</option>\n";
		print "</select>\n";

		print "<select size=\"1\" name=\"RTVACTION\">\n";
		print "<option value=-1 selected>Select Action</option>\n";
		if ($s_guide) {
			print "<option value=1>Refresh Replay</option>\n";
		}
		if ($s_todo) {
			print "<option value=2>To-Do List</option>\n";
		}
		if ($s_guide) {
			print "<option value=3>Manage Shows</option>\n";
		}
		if ($s_guide) {
			print "<option value=4>Manual Recording</option>\n";
		}
		print "</select>\n";

		if (length($icon_go) > 0) {
			print "<input type=image src=\"$imagedir/$icon_go\" ALT=\"Go\">\n";
		}else{
			print "<input type=submit value=\"Go\" name=\"SUBMITRTV\">\n";
		}	
		print "</form>\n";
	}


#	if(($rtvaccess > 0) && ($scheduler eq "rg_scheduler.pl")) {
#		#---------------------------------------------
#		# Add todo list links if todo.pl is executable
#		#---------------------------------------------
#		print "<td valign=top>To-Do list:\n";
#		print "<td valign=top><form action=\"$scriptdir/$scriptname\">\n";
#		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
#		print "<select size=\"1\" name=\"TODO\">\n";
#		for ( split /,/, $replaylist ) {
#			/,/;
#			my $addr = $rtvaddress{$_};
#			my $label = $rtvlabel{$_};
#			print "<option value=$_";
#			#-----------------------------------------------------
#			#if($_ == $inp_selectedrtv) { print " selected"; }
#			#-----------------------------------------------------
#			print ">$label</option>\n";
#		}
#		print "<option value=0 selected>ALL</option>\n</select>\n";
#		print "<td valign=top> ";
#		if (length($icon_go) > 0) {
#			print "<input type=image src=\"$imagedir/$icon_go\" ALT=\"Go\">\n";
#		}else{
#			print "<input type=submit value=\"Go\" name=\"SUBMITTODO\">\n";
#		}	
#		print "</form>\n";
#	}


	print "</tr>\n";
	print "</table>";

	#-------------------------------------------------------------------
	# Third Toolbox Row
	#-------------------------------------------------------------------

	print "<table>";
	print "\n<tr>";


	$form_date = substr($previoustime,0,4) . substr($previoustime,4,2) . substr($previoustime,6,2);
	$form_time = substr($previoustime,8,2);

	print "<td width=5%>";
	if ($prevok) {
		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$form_date\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$form_time\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
		print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";

		if (length($icon_prevwindow) > 0) {
			print "<input type=image src=\"$imagedir/$icon_prevwindow\" ALT=\"<<<\">\n";
		}else{
			print "<input type=submit value=\"<<<\" name=\"SUBMITPW\">";
		}

		print "</form>\n\n";
	}


#	if ($rtvaccess) {
#		print "<td width=10% align=center>";
#		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
#		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
#		print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
#		print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
#		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
#		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
#		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
#		print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
#		print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";
#		print "<input type=hidden name=\"UPDATE\" value=\"ALL\">\n";
#		
#		if (length($icon_refresh) > 0) {
#			print "<input type=image src=\"$imagedir/$icon_refresh\" ALT=\"Refresh ReplayTVs\">\n";
#		}else{
#			print "<input type=submit value=\"Refresh\" name=\"SUBMIT21\">\n";
#		}
#		print "</form>\n\n";
#	}


	print "<td width=50% align=center>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=\"STARTDATE\" value=\"$inp_startdate\">\n";
	print "<input type=hidden name=\"STARTHOUR\" value=\"$inp_starthour\">\n";
	print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
	print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
	print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
	print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
	print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";
	print "<input type=text name=\"SEARCH\" value=\"\" size=40>\n";
	print "<select size=\"1\" name=\"FIELD\">\n";
	print "<option value=\"title\" selected>Title</option>\n";
	print "<option value=\"subtitle\">Episode</option>\n";
	print "<option value=\"description\" >Description</option>\n";
	print "<option value=\"category\">Category</option>\n";
	print "<option value=\"advisories\">Advisories</option>\n";
	
	if ($use_castcrew) {
		print "<option value=\"1\">Actor</option>\n";
		print "<option value=\"2\">Guest Star</option>\n";
		print "<option value=\"3\">Host</option>\n";
		print "<option value=\"4\">Director</option>\n";
		print "<option value=\"5\">Producer</option>\n";
		print "<option value=\"6\">Exec. Producer</option>\n";
		print "<option value=\"7\">Writer</option>\n";
	}
	
	print "</select>\n";

	if (length($icon_find) > 0) {
		print "<input type=image src=\"$imagedir/$icon_find\" ALT=\"Find\">\n";
	}else{
		print "<input type=submit value=\"Find\" name=\"SUBMITFIND\">\n";
	}

	print "</form>\n\n";

	$form_date = substr($endtime,0,4) . substr($endtime,4,2) . substr($endtime,6,2);
	$form_time = substr($endtime,8,2);

	print "<td width=5%>";

	if ($nextok) {
		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
		print "<input type=hidden name=\"STARTDATE\" value=\"$form_date\">\n";
		print "<input type=hidden name=\"STARTHOUR\" value=\"$form_time\">\n";
		print "<input type=hidden name=\"SHOWHOURS\" value=\"$inp_showhours\">\n";
		print "<input type=hidden name=\"SHOWSLOTS\" value=\"$inp_showslots\">\n";
		print "<input type=hidden name=\"FIRSTTUNE\" value=\"$inp_firsttune\">\n";
		print "<input type=hidden name=\"LASTTUNE\" value=\"$inp_lasttune\">\n";
		print "<input type=hidden name=\"FAVORITE\" value=\"$inp_favorite\">\n";

		if (length($icon_nextwindow) > 0) {
			print "<input type=image src=\"$imagedir/$icon_nextwindow\" ALT=\">>>\">\n";
		}else{
			print "<input type=submit value=\">>>\" name=\"SUBMITNW\">\n";
		}

		print "</form>\n\n";
	}

	print "</table><p></font>";

	return 1;

}

#---------------------------------------------------------------------------------------
sub ShowFooter{
	#
	# Show HTML Termination
	#
	# ------------------------------------------------------------------------------

	$prg_end = time;
	$prg_runtime = $prg_end - $prg_start;


	#-------------------------------------------------------------------
	# Close the DB Connection 
	#-------------------------------------------------------------------

	writeDebug("Terminating Database Connection from $DATASOURCE{DSN} ($prgdb_handle)");
	endDSN("",$prgdb_handle);		
	
	&ShowHTTPFooter;

	writeDebug("Exiting ($prg_runtime seconds)");

	writeDebug("********************************************************");

	close;

	return 1;

}

#---------------------------------------------------------------------------------------
sub DoSchedule {
	#
	# Prepare to Schedule a Show 
	# (Actual Scheduling is Done by schedule.pl)
	#
	# ------------------------------------------------------------------------------

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
	my $replayid = "";
	my $replayname = "";
	my $replayaddress = "";
	my $replaydefaultquality = 0;
	my $replaydefaultkeep = 0;

	my $replaylist = "";

	print "<$size_section><font face=\"$font_title\">Program Details</$size_section><p></font>\n";

	#------------------------------------------------------------------------
	# Lookup Program
	#------------------------------------------------------------------------

	my $db_handle = &StartDSN;

	$Stmt = "SELECT * FROM $db_table_tvlistings WHERE programid = '$inp_programid';";

	my $sth = sqlStmt($db_handle,$Stmt);
	if ( $sth ) {
		$row = $sth->fetchrow_hashref;	

		$program_starttime = sqltotimestring($row->{'starttime'});
		$program_tmsprgid = $row->{'tmsprogramid'};
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
		$program_movie = int $row->{'movie'};
		$program_repeat = int $row->{'repeat'};
		$program_starrating = $row->{'starrating'};
		$program_captions = $row->{'captions'};
		$program_channel = $row->{'channel'};
		$program_subtitled = int $row->{'subtitled'};

		($program_stars,$junk) = split(/\//,$program_starrating);

		$fudged_length = 0;

		if (as_epoch_seconds($program_stop) < as_epoch_seconds($program_starttime)) {
			$program_stop = as_time_string($rng_end);
			$fudged_length = 1;
		}

		$program_length = getMinutes($program_starttime,$program_stop);

	}else{
		print "<PRE>Lookup Failed: " . &GetLastSQLStmt() . "\n" . &GetLastSQLError() . "</PRE>";
		return 0;
	}

	endDSN($sth,$db_handle);


	#------------------------------------------------------------------------
	# Cast / Crew Data
	#------------------------------------------------------------------------

	if ($use_castcrew) {
		my $db_handle = &StartDSN;

		$Stmt = "SELECT * FROM $db_table_castcrew WHERE tmsprogramid = '$program_tmsprgid' ORDER BY role;";
	
		my $sth = sqlStmt($db_handle,$Stmt);
		if ( $sth ) {
			while ( my $row = $sth->fetchrow_hashref ) {

				my $program_prodrole = int $row->{'role'};
				my $program_surname = $row->{'surname'};
				my $program_givenname = $row->{'givenname'};
				my $program_productionrole = $productionrole[$program_prodrole];
				$program_rolelist[$program_prodrole] = buildcommastring($program_rolelist[$program_prodrole],convertfromhtml(trimstring("$program_givenname $program_surname")));
			}
		}else{
			print "<PRE>Lookup Failed: " . &GetLastSQLStmt() . "\n" . &GetLastSQLError() . "</PRE>";
			return 0;
		}

		endDSN($sth,$db_handle);

		$program_actor = buildMultiWordList($program_rolelist[1]);
		$program_guest = buildMultiWordList($program_rolelist[2]);
		$program_host = buildMultiWordList($program_rolelist[3]);
		$program_director = buildMultiWordList($program_rolelist[4]);
		$program_producer = buildMultiWordList($program_rolelist[5]);
		$program_eproducer = buildMultiWordList($program_rolelist[6]);
		$program_writer = buildMultiWordList($program_rolelist[7]);
	}else{
		$program_actor = "";
		$program_guest = "";
		$program_host = "";
		$program_director = "";
		$program_producer = "";
		$program_eproducer = "";
		$program_writer = "";
	}

	#------------------------------------------------------------------------
	# Process Record
	#------------------------------------------------------------------------

	$wday = strftime( "%A", localtime(as_epoch_seconds($program_starttime)));
	$dsp_string = $wday . ", " . displaytime($program_starttime);

	my $year = substr($program_starttime,0,4);
	my $month = substr($program_starttime,4,2);
	my $day = substr($program_starttime,6,2);
	my $hour = substr($program_starttime,8,2);
	my $minute = substr($program_starttime,10,2);
	my $seconds = "00";

	print "<hr>\n</CENTER><blockquote><font face=\"$font_detail\"><$size_subsection>\n" . renderhtml($program_title);

	if ($program_subtitle) {
		print ": \"" . renderhtml($program_subtitle) . "\"";
	}

	if ($program_movieyear) {
		print " <small>" . substr($stars,1,$program_stars);
		print " ($program_movieyear, $program_category)</small>";
	}

	print "</$size_subsection>$dsp_string ($program_length minutes) on $program_tuning ($program_channel)<p>\n";

	if ($showpdaformat) {
		print "<small>";
	}

	if (length($program_desc) > 0) {
		print "\"" . renderhtml($program_desc) . "\"<br>\n";
	}

	if (length($program_episodenum) > 0) {
		print "$program_episodenum. ";
	}


	if ((length($program_category) > 0) && ($program_movieyear == 0)) {
		print "($program_category)";
	}

	if (length($program_mpaarating) > 0)  {
		$temp_display = "$program_mpaarating.";
		if ($showchannelicons > 0) {
			if (($program_mpaarating eq "G") && (length($image_mpaag))) {
				$temp_display = buildImage($image_mpaag,$imagedir,$program_mpaarating);
			}
			if (($program_mpaarating eq "PG") && (length($image_mpaapg))) {
				$temp_display = buildImage($image_mpaapg,$imagedir,$program_mpaarating);
			}
			if (($program_mpaarating eq "PG-13") && (length($image_mpaapg13))) {
				$temp_display = buildImage($image_mpaapg13,$imagedir,$program_mpaarating);
			}
			if (($program_mpaarating eq "R") && (length($image_mpaar))) {
				$temp_display = buildImage($image_mpaar,$imagedir,$program_mpaarating);
			}
			if (($program_mpaarating eq "NC17") && (length($image_mpaanc17))) {
				$temp_display = buildImage($image_mpaanc17,$imagedir,$program_mpaarating);
			}
		}
		print " $temp_display";
	}else{ 
		if ($program_movieyear) {
			$temp_display = "NR.";
			if ($showchannelicons > 0) {
				if (length($image_mpaanr)) {
					$temp_display = buildImage($image_mpaanr,$imagedir,"NR");
				}	
			}
			print " $temp_display";

		}
	}

	if (length($program_vchiprating) > 0)  {
		$temp_display = "TV-$program_vchiprating.";
		if ($showchannelicons > 0) {
			if (($program_vchiprating eq "G") && (length($image_tvg))) {
				$temp_display = buildImage($image_tvg,$imagedir,"TV-$program_vchiprating");
			}
			if (($program_vchiprating eq "PG") && (length($image_tvpg))) {
				$temp_display = buildImage($image_tvpg,$imagedir,"TV-$program_vchiprating");
			}
			if (($program_vchiprating eq "14") && (length($image_tv14))) {
				$temp_display = buildImage($image_tv14,$imagedir,"TV-$program_vchiprating");
			}
			if (($program_vchiprating eq "MA") && (length($image_tvma))) {
				$temp_display = buildImage($image_tvma,$imagedir,"TV-$program_vchiprating");
			}
			if (($program_vchiprating eq "Y") && (length($image_tvy))) {
				$temp_display = buildImage($image_tvy,$imagedir,"TV-$program_vchiprating");
			}
			if (($program_vchiprating eq "Y7") && (length($image_tvy7))) {
				$temp_display = buildImage($image_tvy7,$imagedir,"TV-$program_vchiprating");
			}
		}
		print " $temp_display";
	}

	if (length($program_captions) > 0)  {
		$temp_display = "CC";
		if ($showchannelicons > 0) {
			if (length($image_cc) > 0) {
				$temp_display = buildImage($image_cc,$imagedir,"CC");
			}
		}
		print " $temp_display";
	}
	
	if ($program_stereo) {
		$temp_display = "Stereo.";
		if ($showchannelicons > 0) {
			if (length($image_stereo) > 0) {
				$temp_display = buildImage($image_stereo,$imagedir,"Stereo");
			}
		}
		print " $temp_display";
	}

	if ($program_repeat) {
		$temp_display = "(Repeat)";
		if ($showchannelicons > 0) {
			if (length($image_repeat) > 0) {
				$temp_display = buildImage($image_repeat,$imagedir,"Repeat");
			}
		}
		print " $temp_display";
	}


	if (length($program_advisories) > 0) {
		print " <small>($program_advisories)</small>";
	}
	
	if (length($program_actor) > 0) {
		print " <small>Cast: $program_actor.</small>";
	}

	if (length($program_host) > 0) {
		print " <small>Host: $program_host.</small>";
	}

	if (length($program_guest) > 0) {
		print " <small>Guests: $program_guest.</small>";
	}

	if (length($program_eproducer) > 0) {
		print " <small>Executive Producer: $program_eproducer.</small>";
	}

	if (length($program_producer) > 0) {
		print " <small>Produced by $program_producer.</small>";
	}


	if (length($program_writer) > 0) {
		print " <small>Written by $program_writer.</small>";
	}

	if (length($program_director) > 0) {
		print " <small>Directed by $program_director.</small>";
	}


        if (as_epoch_seconds($program_stop) < as_epoch_seconds($now_timestring))  {
		#------------------------
                # Past show
		#------------------------
		$program_timing = 0;
        }elsif (as_epoch_seconds($program_start) < as_epoch_seconds($now_timestring))  {
		#------------------------
                # Current show
		#------------------------
		$program_timing = 1;
        } else {
		#------------------------
                # Future show
		#------------------------
		$program_timing = 2;
	}
	$bgcolor = $color_show[$program_timing];

	if($rtvaccess) {
		$program_icon = getScheduleDetails($inp_programid,$program_timing);
	}
	if (length($bgcolor) > 0) {
		$bgcolor = " bgcolor=\"$bgcolor\"";
	}
	if (length($program_icon) > 0) {
		print "<br>\n$program_icon";
	}


	print "</blockquote>\n";


	if ($showpdaformat) {
		print "</small>";
	}

	print "<p><CENTER>\n";
	print "<table border=0><tr>";

	print "<td>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=SEARCH value=\"$program_title\">\n";
	if (length($icon_findall) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_findall\" ALT=\"Find All\">\n";
	}else{
		print "<input type=submit value=\"Find All\" name=\"FIND\">\n";
	}
	print "</form>\n";
	print "<td>";
	

	print "<td>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=SEARCH value=\"$program_title|$program_subtitle\">\n";
	print "<input type=hidden name=FIELD value=\"title,subtitle\">\n";
	if (length($icon_findrepeat) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_findrepeat\" ALT=\"Find Repeats\">\n";
	}else{
		print "<input type=submit value=\"Find Repeats\" name=\"FINDREPEATS\">\n";
	}
	print "</form>\n";
	print "<td>";
	
	print "<form method=POST action=\"$scriptdir/$scriptname#$inp_programid\">\n";
	print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";
	print "<input type=hidden name=STARTDATE value=\"" . substr($program_true_start,0,8) . "\">";
	print "<input type=hidden name=STARTHOUR value=\"" . substr($program_true_start,8,2) . "\">";
	print "<input type=hidden name=SHOWHOURS value=\"$inp_showhours\">";
	print "<input type=hidden name=SHOWSLOTS value=\"$inp_showslots\">";
	if (length($icon_locate) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_locate\" ALT=\"Locate\">\n";
	}else{
		print "<input type=submit value=\"Locate\" name=\"LOCATE\">\n";
	}
	print "</form>\n";
	print "<td>";

	#------------------------------------------------------------------------
	# If there isn't access to RTV, this is simply a program details screen
	#------------------------------------------------------------------------

	if (!$rtvaccess) {
		writeDebug("doschedule::No RTV Access");

		print " <form method=POST action=\"$scriptdir/$scriptname\">";
		if (length($inp_search) > 0) {
			print "<input type=hidden name=SEARCH value=\"$inp_search\">";
			print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";
		}else{
			print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";
			print "<input type=hidden name=STARTDATE value=\"$inp_startdate\">";
			print "<input type=hidden name=STARTHOUR value=\"$inp_starthour\">";
			print "<input type=hidden name=SHOWHOURS value=\"$inp_showhours\">";
			print "<input type=hidden name=SHOWSLOTS value=\"$inp_showslots\">";
		}

		if (length($icon_done) > 0) {
			print "\n<input type=image src=\"$imagedir/$icon_done\" ALT=\"Done\">\n";
		}else{
			print "<input type=submit value=\"Done\" name=\"DONE\">\n";
		}

	
		print "</form>";
		print "<td>";
		print "</table>";
		print "</CENTER><p>";

		return 1;
	}

	print "</table>";
	print "</CENTER><p>";

	if (countArray($schedulinglist,";") < 1) {
		if (countArray($replaylist,",") > 0) {
			print "<p><CENTER><$size_subsection>No ReplayTV Units With Remote Scheduling Found</$size_subsection><p>";
		}else{
			print "<p><CENTER><$size_subsection>No ReplayTV Units Defined</$size_subsection><p>";
		}
		print "<form method=POST action=\"$scriptdir/$scriptname\">";
		if (length($inp_search) > 0) {
			print "<input type=hidden name=SEARCH value=\"$inp_search\">";
			print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";
		}else{
			print "<input type=hidden name=STARTDATE value=\"$inp_startdate\">";
			print "<input type=hidden name=STARTHOUR value=\"$inp_starthour\">";
			print "<input type=hidden name=SHOWHOURS value=\"$inp_showhours\">";
			print "<input type=hidden name=SHOWSLOTS value=\"$inp_showslots\">";
			print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";
		}
		print "<input type=submit value=\"Done\" name=\"SUBMIT\"></form></CENTER><p>";
		return 1;
	}

	print "</FONT></CENTER><CENTER>";

	print "<hr>\n";

	print "<$size_section><font face=\"$font_title\">Schedule a Recording</$size_section><p></font>\n";
		
	if (countArray($schedulinglist,";") == 1) {
		$inp_selectedrtv = $schedulinglist;
	}

	if (!$inp_recordtype) {

		$url_parms = "";
		addParameter("PROGRAMID",$inp_programid);

		print "\n<form method=POST action=\"$scriptdir/$scriptname$url_parms\">\n";
		print "<table>\n";
		print "<input type=hidden name=PROGRAMID value=\"$inp_programid\">";
		print "<input type=hidden name=STARTDATE value=\"$inp_startdate\">";
		print "<input type=hidden name=STARTHOUR value=\"$inp_starthour\">";
		print "<input type=hidden name=SHOWHOURS value=\"$inp_showhours\">";
		print "<input type=hidden name=SHOWSLOTS value=\"$inp_showslots\">";
		print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";

		if (length($inp_search) > 0) {
			print "<input type=hidden name=SEARCH value=\"$inp_search\">";
		}
		if (length($inp_selectedrtv) < 1) {
			print "<tr>\n";
			print "<td align=right><B>ReplayTV:</B></td>\n";
			print "<td><select size=\"1\" name=\"SELECTEDRTV\">\n";

			for ( split /;/, $schedulinglist ) {
				/;/;
				if ($rtvlabel{$_} eq $defaultreplaytv) {
					print "<option value=\"$_\" selected>$rtvlabel{$_}</option>\n";
				}else{
					print "<option value=\"$_\">$rtvlabel{$_}</option>\n";
				}
			}
			print "</select></td></tr>\n";
		}else{
			print "<tr><td align=right><B>ReplayTV:</B></td><td>";
			print $rtvlabel{$inp_selectedrtv};
			print " ($rtvaddress{$inp_selectedrtv})";
			print "</td></tr>\n";

			print "<input type=hidden name=\"SELECTEDRTV\" value=\"$inp_selectedrtv\">\n";
		}

		print "<tr><td align=right><B>Record:</B></td>\n";
		print "<td>";
		print "<select size=\"1\" name=\"RECORDTYPE\">\n";
		print "<option value=\"1\">First run and repeats</option>\n";
		print "<option value=\"2\">First run episodes</option>\n";
		print "<option value=\"3\">This show only</option>\n";
		print "</select>\n";
		print "</td></tr></table>\n";
	
		if (length($icon_select) > 0) {
			print "<input type=image src=\"$imagedir/$icon_select\" ALT=\"Select\">\n";
		}else{
			print "<input type=submit value=\"Select\" name=\"SUBMITSEL\">\n";
		}

		print "</form><p>\n";

		return 1;
	}

	print "<form method=POST action=\"$scriptdir/$schedulename?STATE=slotrequest\">\n";
	if (!$showpdaformat) {
		print "<table>\n";
		print "<tr><td align=right>";
	}else{
		print "</CENTER>";
	}

	print "<B>ReplayTV:</B>";
	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}
	print $rtvlabel{$inp_selectedrtv};
	print " ($rtvaddress{$inp_selectedrtv})";
	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<p>";
	}

	print "\n";

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Record:</B>";

	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}

	if ($inp_recordtype == 1) {
		print "First run and repeats";
	}

	if ($inp_recordtype == 2) {
		print "First run episodes";
	}

	if ($inp_recordtype == 3) {
		print "This show only";
	}

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<p>";
	}
	print "\n";


	#------------------------------------------------------------------------
	# Known Fields
	#------------------------------------------------------------------------


	if ($allowtitleedit) {
		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}
		print "<B>Show Title:</B>";
		
		if (!$showpdaformat) {
			print "</td>";
		}else{
			print " ";
		}
		print "\n";

		if (!$showpdaformat) {
			print "<td>";
		}

		print "<input type=text name=\"SHOWTITLE\" value=\"$program_title\" size=50>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}

		print "\n";

	}else{
		print "<input type=hidden name=\"SHOWTITLE\" value=\"$program_title\">\n";
	}

	print "<input type=hidden name=\"MONTH\" value=\"$month\">\n";
	print "<input type=hidden name=\"YEAR\" value=\"$year\">\n";
	print "<input type=hidden name=\"DAY\" value=\"$day\">\n";
	print "<input type=hidden name=\"HOUR\" value=\"$hour\">\n";
	print "<input type=hidden name=\"MINUTE\" value=\"$minute\">\n";
	print "<input type=hidden name=\"LENGTH\" value=\"$program_length\">\n";
	print "<input type=hidden name=\"TUNING\" value=\"$program_tuning\">\n";
	print "<input type=hidden name=\"ISMANUAL\" value=\"0\">\n";
	if ($rtvport{$inp_selectedrtv} != 80) {
		print "<input type=\"hidden\" name=\"REPLAYTV\" value=\"$rtvaddress{$inp_selectedrtv}:$rtvport{$inp_selectedrtv}\">\n";
	}else{
		print "<input type=\"hidden\" name=\"REPLAYTV\" value=\"$rtvaddress{$inp_selectedrtv}\">\n";
	}
	print "<input type=hidden name=\"RECORDTYPE\" value=\"$inp_recordtype\">\n";


	if ($inp_recordtype == 3) {
		#------------------------------------------------------------------------
		# Keep Until (This Show Only)
		#------------------------------------------------------------------------

		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}
		print "<B>Keep Until:</B>";
		
		if (!$showpdaformat) {
			print "</td>";
		}else{
			print " ";
		}
		print "\n";

		if (!$showpdaformat) {
			print "<td>";
		}
		print "<select size=\"1\" name=\"GUARANTEED\">\n";
		print "<option value=\"1\">I delete</option>\n";
		print "<option value=\"0\">Space needed</option>\n";
		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}

		print "\n";

		print "<input type=\"hidden\" name=\"KEEP\" value=\"1\">\n";
	}else{
		#------------------------------------------------------------------------
		# Episodes to Keep
		#------------------------------------------------------------------------

		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}
		print "<B>Episodes to Keep:</B>";

		if (!$showpdaformat) {
			print "</td>";
		}else{
			print " ";
		}

		print "\n";

		if (!$showpdaformat) {
			print "<td>";
		}

		print "<select size=\"1\" name=\"KEEP\">";
		selectNumbers($rtvdefaultkeep{$inp_selectedrtv},10,1);
		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}
		print "\n";

		#------------------------------------------------------------------------
		# Delete oldest
		#------------------------------------------------------------------------


		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}
		print "<B>Delete oldest:</B>";

		if (!$showpdaformat) {
			print "</td>";
		}else{
			print " ";
		}
		print "\n";


		if (!$showpdaformat) {
			print "<td>";
		}
		print "<select size=\"1\" name=\"GUARANTEED\">\n";
		print "<option value=\"1\">Only for new episode</option>\n";
		print "<option value=\"0\">If space needed</option>\n";
		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}

		print "\n";
	}
 
	#------------------------------------------------------------------------
	# Quality
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<tr>\n";
		print "<td align=right>";
	}

	print "<B>Quality:</B>";

	if (!$showpdaformat) {
		print "</td>";
	}else{
		print " ";
	}
	print "\n";

	if (!$showpdaformat) {
		print "<td>";	
	}
	print "\n";

	print "<select size=\"1\" name=\"QUALITY\">\n";
	if ($rtvdefaultquality{$inp_selectedrtv} == 2) {
		print "<option value=\"2\" selected>Standard</option>\n";
	}else{
		print "<option value=\"2\">Standard</option>\n";
	}
	if ($rtvdefaultquality{$inp_selectedrtv} == 1) {
		print "<option value=\"1\" selected>Medium</option>\n";
	}else{
		print "<option value=\"1\">Medium</option>\n";
	}
	if ($rtvdefaultquality{$inp_selectedrtv} == 0) {
		print "<option value=\"0\" selected>High</option>\n";
	}else{
		print "<option value=\"0\">High</option>\n";
	}
	print "</select>\n";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}
	print "\n";


	#------------------------------------------------------------------------
	# Advanced Options
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<tr><td><p></td><td></td></tr>\n";
		print "<tr><td></td><td align=left>";
	}

	print "<font size=+1><B><I>Advanced Settings</I></B></font><p>";

	if (!$showpdaformat) {
		print "</td></tr>\n";
		print "<tr><td><p></td><td></td></tr>\n";
	}


	#------------------------------------------------------------------------
	# Padding
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Start recording:</B>";

	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}
	print "<input type=text size=\"3\" name=\"PREPAD\" value=\"0\"> min. before";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}
	print "\n";


	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>End recording:</B>";

	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}

	print "<input type=text size=\"3\" name=\"POSTPAD\" value=\"0\"> min. after";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}
	print "\n";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}
	print "\n";


	#------------------------------------------------------------------------
	# Category
	#------------------------------------------------------------------------
	

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Store in category:</B>";

	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}

	print "<select size=\"1\" name=\"CATEGORY\">";
	print "<option value=\"255\" selected>All Shows</option>\n";

	$ctr = 0;

	if (countArray($categories{$inp_selectedrtv},";")) {
		for ( split /;/, $categories{$inp_selectedrtv} ) {
			/;/;
			($cat_num,$cat_label) = split(',', $_, 2);
			print "<option value=\"$cat_num\">$cat_label</option>\n";	
			$ctr++;
		}
	}
	print "</select>";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}

	print "\n";

	#------------------------------------------------------------------------
	# Days of Week
	#------------------------------------------------------------------------

	if ($inp_recordtype == 3) {
		print "<input type=hidden name=\"SUN\" value=\"1\">\n";
		print "<input type=hidden name=\"MON\" value=\"1\">\n";
		print "<input type=hidden name=\"TUE\" value=\"1\">\n";
		print "<input type=hidden name=\"WED\" value=\"1\">\n";
		print "<input type=hidden name=\"THU\" value=\"1\">\n";
		print "<input type=hidden name=\"FRI\" value=\"1\">\n";
		print "<input type=hidden name=\"SAT\" value=\"1\">\n";
	}else{
		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}

		print "<B>Record shows on:</B>";

		if (!$showpdaformat) {
			print "</td>\n<td>";
		}else{
			print "<br>";
		}

		print "<input type=checkbox name=\"SUN\" value=\"1\" checked> Sun.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"MON\" value=\"1\" checked> Mon.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"TUE\" value=\"1\" checked> Tue.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"WED\" value=\"1\" checked> Wed.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"THU\" value=\"1\" checked> Thu.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"FRI\" value=\"1\" checked> Fri.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"SAT\" value=\"1\" checked> Sat.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}

		print "\n";
	}

	#------------------------------------------------------------------------
	# Set up Return Path
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "\n<tr><td></td><td>";
	}else{
		print "<p>\n";
	}

	if (length($inp_search) > 0) {
		$url_parms = "";
		addParameter("SEARCH",$inp_search);
		addParameter("SHOWPDAFORMAT",$showpdaformat);
		writeDebug("doschedule::ReturnPath: $scriptdir/$scriptname$url_parms");
		print "\n<input type=hidden name=RETURNURL value=\"$scriptdir/$scriptname?SEARCH=$inp_search&SHOWPDAFORMAT=$showpdaformat\">\n";
		print "\n<input type=hidden name=RETURNTEXT value=\"Back to Search Results\">\n";
	}else{
		$url_parms = "";
		addParameter("PROGRAMID",$inp_programid);
		addParameter("STARTDATE",$inp_startdate);
		addParameter("STARTHOUR",$inp_starthour);
		addParameter("SHOWHOURS",$inp_showhours);
		addParameter("SHOWSLOTS",$inp_showslots);
		addParameter("SHOWPDAFORMAT",$showpdaformat);
		addParameter("UPDATE",$rtvaddress{$inp_selectedrtv});

		writeDebug("doschedule::ReturnPath: $scriptdir/$scriptname$url_parms");
		print "\n<input type=hidden name=RETURNURL value=\"$scriptdir/$scriptname$url_parms\">\n";
		print "\n<input type=hidden name=RETURNTEXT value=\"Back to Schedule\">\n";
	}

	#------------------------------------------------------------------------
	# Integrate schedule.pl with our font/color scheme
	#------------------------------------------------------------------------

	print "<input type=hidden name=PRGCONF value=\"$configfile\">\n";
	print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";

	if (length($icon_schedule) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_schedule\" ALT=\"Schedule\">\n";
	}else{
		print "\n<input type=submit value=Schedule name=SUBMIT>\n";
	}


	print "</form><p>";

	if (!$showpdaformat) {
		print "</td></tr>\n</table>";
	}

	print "\n";

	return 1;
}

#---------------------------------------------------------------------------------------
sub DoSearch {
	#
	# Perform a Search
	#
	# ------------------------------------------------------------------------------

	my $specialdebug = 1;
	my $searchmode = 0;

	if ($inp_searchfield eq $null) {
		$inp_searchfield = "title";
	}

	if (int $inp_searchfield > 0) {
		#-------------------------------
		# If it's a number, we're 
		# searching the cast crew table
		#-------------------------------
		$searchmode = 1;
	}

	if ($specialdebug) {
		writeDebug("dosearch::inp_searchfield:  $inp_searchfield, inp_search: $inp_search, searchmode: $searchmode, searchfutureonly: $searchfutureonly");
	}

	if ($inp_searchfield eq "title,subtitle") {
		($inp_search1,$inp_search2) = split(/\|/,$inp_search);	
		if ($inp_search2 eq $null) {
			$inp_searchfield = "title";
			$inp_search = $inp_search1;
		}
	}

	my $db_handle = &StartDSN;


	if ($inp_searchfield eq "title,subtitle") {
		if ($searchfutureonly) {
			writeDebug("dosearch::Searching Future Only for $inp_search1 (title) $inp_search2 (subtitle)");

			$Stmt = "";
			$Stmt .= "SELECT * ";
			$Stmt .= "FROM $db_table_tvlistings, $db_table_channels ";
			$Stmt .= "WHERE (((((title LIKE '%" . filterfield($inp_search1) . "%' AND subtitle LIKE '%'". filterfield($inp_search2) . "%' ) AND endtime > '$sql_now') AND $db_table_tvlistings.tuning = $db_table_channels.tuning) AND $db_table_tvlistings.channel = $db_table_channels.channel) AND $db_table_channels.hidden = 0 ";
			$Stmt .= "ORDER BY starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel, $inp_searchfield;";
		}else{
			writeDebug("dosearch::Searching for $inp_search1 (title) $inp_search2 (subtitle)");
	
			$Stmt = "";
			$Stmt .= "SELECT * ";
			$Stmt .= "FROM $db_table_tvlistings, $db_table_channels ";
			$Stmt .= "WHERE (((title LIKE '%" . filterfield($inp_search1) . "%' AND subtitle LIKE '%" . filterfield($inp_search2) . "%') AND $db_table_tvlistings.tuning = $db_table_channels.tuning) AND $db_table_tvlistings.channel = $db_table_channels.channel) AND $db_table_channels.hidden = 0 ";
			$Stmt .= "ORDER BY starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel, $inp_searchfield;";
		}
	}else{
		if ($searchmode == 0) {
			if ($searchfutureonly) {
				writeDebug("dosearch::Searching Future Only for $inp_search within $inp_searchfield");

				$Stmt = "";
				$Stmt .= "SELECT * ";
				$Stmt .= "FROM $db_table_tvlistings, $db_table_channels ";
				$Stmt .= "WHERE (((($inp_searchfield LIKE '%" . filterfield($inp_search) . "%') AND endtime > '$sql_now') AND $db_table_tvlistings.tuning = $db_table_channels.tuning) AND $db_table_tvlistings.channel = $db_table_channels.channel) AND $db_table_channels.hidden = 0 ";
				$Stmt .= "ORDER BY starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel, $inp_searchfield;";
			}else{
				writeDebug("dosearch::Searching for $inp_search within $inp_searchfield");

				$Stmt = "";
				$Stmt .= "SELECT * ";
				$Stmt .= "FROM $db_table_tvlistings, $db_table_channels ";
				$Stmt .= "WHERE ((($inp_searchfield LIKE '%" . filterfield($inp_search) . "%') AND $db_table_tvlistings.tuning = $db_table_channels.tuning) AND $db_table_tvlistings.channel = $db_table_channels.channel) AND $db_table_channels.hidden = 0 ";
				$Stmt .= "ORDER BY starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel, $inp_searchfield;";
			}

		}
		if ($searchmode == 1) {
			#
			# break field into surname, givenname and search on role #
			#

			my($givenname,$surname) = $inp_search =~ /^(.*?) (\S+)$/;

			if (($givenname eq "") && ($surname eq "")) {
				$surname = $inp_search;
			}

			if ($searchfutureonly) {
				writeDebug("dosearch::Searching Future Only for $inp_search within " . $productionrole[$inp_searchfield]);

				$Stmt = "";
				$Stmt .= "SELECT * ";
				$Stmt .= "FROM $db_table_tvlistings, $db_table_channels, $db_table_castcrew ";
				$Stmt .= "WHERE ((($db_table_castcrew.surname = '" . filterfield($surname) . "' "; 
				if (length($givenname) > 0) {
					$Stmt .= "AND $db_table_castcrew.givenname = '" . filterfield($givenname) . "' ";
				}
				$Stmt .= ") AND $db_table_castcrew.role = $inp_searchfield ";
			        $Stmt .= " ) AND endtime > '$sql_now') AND $db_table_tvlistings.tmsprogramid = $db_table_castcrew.tmsprogramid AND $db_table_tvlistings.tuning = $db_table_channels.tuning AND $db_table_tvlistings.channel = $db_table_channels.channel AND $db_table_channels.hidden = 0 ";
				$Stmt .= "ORDER BY starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel;";
			}else{
				$Stmt = "";
				$Stmt .= "SELECT * ";
				$Stmt .= "FROM $db_table_tvlistings, $db_table_channels, $db_table_castcrew ";
				$Stmt .= "WHERE (($db_table_castcrew.surname = '" . filterfield($surname) . "' "; 
				if (length($givenname) > 0) {
					$Stmt .= "AND $db_table_castcrew.givenname = '" . filterfield($givenname) . "' ";
				}
				$Stmt .= ") AND $db_table_castcrew.role = $inp_searchfield ";
			        $Stmt .= " ) AND $db_table_tvlistings.tmsprogramid = $db_table_castcrew.tmsprogramid AND $db_table_tvlistings.tuning = $db_table_channels.tuning AND $db_table_tvlistings.channel = $db_table_channels.channel AND $db_table_channels.hidden = 0 ";
				$Stmt .= "ORDER BY starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel;";
			}

			$inp_searchfield = $productionrole[$inp_searchfield];

		}
	}

	if ($debug) {
		print "<PRE>SQL: $Stmt\n</PRE>";
	}

	if ($specialdebug) {
		writeDebug("dosearch::SQL: $Stmt");
	}

	$records = 0;

	print "<font face=\"$font_detail\">";

	my $sth = sqlStmt($db_handle,$Stmt);
	if ( $sth ) {

		while ( $row = $sth->fetchrow_hashref ) {
			$records++;

			$program_id = $row->{'programid'};
			$program_start = sqltotimestring($row->{'starttime'});
			$program_true_start = $program_start;
			$program_stop = sqltotimestring($row->{'endtime'});
			$program_title = $row->{'title'};
			$program_subtitle = $row->{'subtitle'};
			$program_desc = $row->{'description'};
			$program_tuning = $row->{'tuning'};
			$program_channel = $row->{'channel'};
			$program_advisories = $row->{'advisories'};
			$program_category = $row->{'category'};
			$program_mpaarating = $row->{'mpaarating'};
			$program_vchiprating = $row->{'vchiprating'};
			$program_episodenum = $row->{'episodenum'};
			$program_movieyear = int $row->{'movieyear'};
			$program_stereo = int $row->{'stereo'};
			$program_repeat = int $row->{'repeat'};
			$program_starrating = $row->{'starrating'};
			$program_captions = $row->{'captions'};
			$program_theme = $row->{'theme'};

			($program_stars,$junk) = split(/\//,$program_starrating);

			#----------------------------------------------------------------------------
			# Because in it's infinite wisdom XMLTV does not provide a STOP time
			# at the end of the listings, if we're looking at the last available
			# data we can't calculate an endpoint so we just make something up.
			# (Basically we give it one slot)
			#----------------------------------------------------------------------------

			$fudged_length = 0;

			if (as_epoch_seconds($program_stop) < as_epoch_seconds($program_start)) {
				$program_stop = as_time_string(as_epoch_seconds($program_start) + ($inp_showslots * 60));
				$fudged_length = 1;
			}
	

			$program_length = getMinutes($program_start,$program_stop);
			$display_length = $program_length;
			$program_time = "";
			$program_extra = "";

			
			$wday = substr(strftime( "%A", localtime(as_epoch_seconds($program_start))),0,3);
			$dsp_string = $wday . ", " . displaytime($program_start);

			$program_starthour = substr($program_start,8,2);
			$program_startdate = substr($program_start,0,8);

			$starttime = $inp_startdate . $starthour . "0000";

        		if (as_epoch_seconds($program_stop) < as_epoch_seconds($now_timestring))  {
				#--------------------------
        		        # Past show
				#--------------------------
				$program_timing = 0;
        		}elsif (as_epoch_seconds($program_start) < as_epoch_seconds($now_timestring))  {
				#--------------------------
        		        # Current show
				#--------------------------
				$program_timing = 1;
		        } else {
				#--------------------------
              		  	# Future show
				#--------------------------
				$program_timing = 2;
			}
			$bgcolor = $color_show[$program_timing];
			if($rtvaccess) {
				$program_icon = getScheduleDetails( $program_id , $program_timing );
			}
			if (length($bgcolor) > 0) {
				$bgcolor = " bgcolor=\"$bgcolor\"";
			}
	
			if ($records == 1) {
				if (!$showpdaformat) {
					print "<table border=1>";
					print "<tr>";
					print "<td width=\"20%\" align=left valign=top bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" color=\"$color_headingtext\">Date</font>";
					print "<td width=\"10%\" align=left valign=top bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" color=\"$color_headingtext\">Channel</font>";
					print "<td width=\"70%\" align=left valign=top bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" color=\"$color_headingtext\">Title</font>";
					#print "<td width=12% align=left valign=top bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" color=\"$color_headingtext\">Attributes</font>";
					print "</tr>";
				}else{
					print "<p>";
				}
			}

			if (!$showpdaformat) {
				print "<tr>";
				print "<td align=left valign=top $bgcolor><font size=2 face=\"$font_listings\">";
			}else{
				print "<$size_pdalistings>";
			}


			$url_parms = "";
			addParameter("STARTDATE",$program_startdate);
			addParameter("STARTHOUR",$program_starthour);
			addParameter("SHOWHOURS",$inp_showhours);
			addParameter("SHOWSLOTS",$inp_showslots);
			addParameter("SHOWPDAFORMAT",$showpdaformat);

			print "<a href=\"$scriptdir/$scriptname$url_parms\">";
			print $dsp_string;
			print "</a>\n";

			if (!$showpdaformat) {
				print "<td align=left valign=top $bgcolor><font size=2 face=\"$font_listings\">";
			}else{
				print " ";
			} 

			#------------------------------------------------------------------------
			# Add a link to show just the single channel with 2 days of listings
			#------------------------------------------------------------------------

			$url_parms = "";
			addParameter("FIRSTTUNE",$program_tuning);
			addParameter("LASTTUNE",program_tuning);
			addParameter("STARTDATE",$program_startdate);
			addParameter("STARTHOUR",$program_starthour);
			addParameter("SHOWHOURS","48");
			addParameter("SHOWSLOTS",$inp_showslots);
			addParameter("SHOWPDAFORMAT",$showpdaformat);

			print "$program_tuning (<a href=\"$scriptdir/$scriptname$url_parms\">$program_channel</a>)\n";

			#------------------------------------------------------------------------
			# Force some variables so the odd start times aren't 
			# duplicated in the render
			#------------------------------------------------------------------------
			$starttime = $program_true_start;
			$colpos = 1;
			$colspan = 1;
			$shortslot = 0;
			#$showrtvtext = 1;

			&RenderShow;

			if (!$showpdaformat) {
				print "</tr>\n";
			}else{
				print "<p>\n";
			}
		}
	}else{
	}

	print "</table><p>";

	if ($inp_searchfield eq "title,subtitle") {
		$inp_search = "$inp_search1\" and \"$inp_search2";
		$inp_searchfield = "title and episode title";
	}

	if ($inp_searchfield eq "subtitle") {
		$inp_searchfield = "episode title";
	}

	if ($records) {
			writeDebug("dosearch::Search Returned $records Rows");
			print "<p><font face=\"$font_menu\">Found $records show(s) matching \"$inp_search\" within $inp_searchfield.<p></font>";
	}else{
			writeDebug("dosearch::Search Did Not Return Any Rows");
			print "<p><font face=\"$font_menu\">Did not find any matches for \"$inp_search\" within $inp_searchfield.<p></font>";
	}

	endDSN($sth,$db_handle);

	return 1;

}

#---------------------------------------------------------------------------------------
sub DoToDo {
	#
	# Display the To-Do list
	#
	# Options:
	#	replayguide.conf	todofromstart - if 1 then todo time ranges will
	#				                be from program start instead of
	#						end.
	#
	#	replayguide.conf	todooption	0 - ALL
	#						1 - From Today
	#						1 - From Right Now
	#
	# ------------------------------------------------------------------------------
	my $label = $rtvlabel{$inp_todo};

	if($label eq "") {
		$label = "ALL";
		$inp_todo = 0;
	}

	if ($todooption == 0) {
		
		#------------------------------------------------------
		# All
		#------------------------------------------------------

		writeDebug("dotodo::Searching for $label");

		$Stmt = "";
		$Stmt .= "SELECT * FROM $db_table_schedule,$db_table_tvlistings WHERE ";
		if($inp_todo > 0) {
			$Stmt .= "(replayid = $inp_todo) AND ";
		}
		$Stmt .= "($db_table_schedule.programid = $db_table_tvlistings.programid) ";
		$Stmt .= "ORDER BY $db_table_tvlistings.starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel, title;";
	}


	if ($todooption == 1) {

		#------------------------------------------------------
		# From Today
		#------------------------------------------------------

		writeDebug("dotodo::Searching From Today for $label");


		$Stmt = "";
		$Stmt .= "SELECT * FROM $db_table_schedule,$db_table_tvlistings WHERE ";
		if($inp_todo > 0) {
			$Stmt .= "(replayid = $inp_todo) AND ";
		}
		$Stmt .= "($db_table_schedule.programid = $db_table_tvlistings.programid) ";
		if ($todofromstart) {
			$Stmt .= " AND $db_table_tvlistings.starttime > '$sql_today'";
		}else{
			$Stmt .= " AND $db_table_tvlistings.endtime > '$sql_today'";
		}
		$Stmt .= "ORDER BY $db_table_tvlistings.starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel, title;";
	}

	if ($todooption == 2) {

		#------------------------------------------------------
		# From Now
		#------------------------------------------------------

		writeDebug("dotodo::Searching Future Only for $label");


		$Stmt = "";
		$Stmt .= "SELECT * FROM $db_table_schedule,$db_table_tvlistings WHERE ";
		if($inp_todo > 0) {
			$Stmt .= "(replayid = $inp_todo) AND ";
		}
		$Stmt .= "($db_table_schedule.programid = $db_table_tvlistings.programid) ";
		if ($todofromstart) {
			$Stmt .= " AND $db_table_tvlistings.starttime > '$sql_now'";
		}else{
			$Stmt .= " AND $db_table_tvlistings.endtime > '$sql_now'";
		}
		$Stmt .= "ORDER BY $db_table_tvlistings.starttime, $db_table_tvlistings.tuning, $db_table_tvlistings.channel, title;";
	}


	if ($debug) {
		print "<PRE>SQL: $Stmt\n</PRE>";
	}

	
	$records = 0;
	$last_program_id = 0;

	print "<font face=\"$font_detail\">";

	my $db_handle = &StartDSN;

	my $sth = sqlStmt($db_handle,$Stmt);

	if ($sth) {

		while ( $row = $sth->fetchrow_hashref ) {
			$records++;

			$program_id = $row->{'programid'};
			# Skip over duplicate programs (scheduled on multiple units)
			if($program_id eq $last_program_id) {
				next;
			}
			$last_program_id = $program_id;

			$program_start = sqltotimestring($row->{'starttime'});
			$program_true_start = $program_start;
			$program_stop = sqltotimestring($row->{'endtime'});
			$program_title = $row->{'title'};
			$program_subtitle = $row->{'subtitle'};
			$program_desc = $row->{'description'};
			$program_tuning = $row->{'tuning'};
			$program_channel = $row->{'channel'};
			$program_advisories = $row->{'advisories'};
			$program_category = $row->{'category'};
			$program_mpaarating = $row->{'mpaarating'};
			$program_vchiprating = $row->{'vchiprating'};
			$program_episodenum = $row->{'episodenum'};
			$program_movieyear = int $row->{'movieyear'};
			$program_stereo = int $row->{'stereo'};
			$program_repeat = int $row->{'repeat'};
			$program_starrating = $row->{'starrating'};
			$program_captions = $row->{'captions'};
			$program_theme = $row->{'theme'};

			($program_stars,$junk) = split(/\//,$program_starrating);

			#----------------------------------------------------------------------------
			# Because in it's infinite wisdom XMLTV does not provide a STOP time
			# at the end of the listings, if we're looking at the last available
			# data we can't calculate an endpoint so we just make something up.
			# (Basically we give it one slot)
			#----------------------------------------------------------------------------

			$fudged_length = 0;

			if (as_epoch_seconds($program_stop) < as_epoch_seconds($program_start)) {
				$program_stop = as_time_string(as_epoch_seconds($program_start) + ($inp_showslots * 60));
				$fudged_length = 1;
			}
	

			$program_length = getMinutes($program_start,$program_stop);
			$display_length = $program_length;
			$program_time = "";
			$program_extra = "";

			$rng_string = substr(as_time_string(as_epoch_seconds($program_true_start)),0,8);
			$wday = strftime( "%A", localtime(as_epoch_seconds($program_true_start)));
			$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2) . "/" . substr($rng_string,0,4);
			
			$program_starthour = substr($program_start,8,2);
			$program_startdate = substr($program_start,0,8);

			$starttime = $inp_startdate . $starthour . "0000";

        		if (as_epoch_seconds($program_stop) < as_epoch_seconds($now_timestring))  {
        		        # Past show
				$program_timing = 0;
        		}elsif (as_epoch_seconds($program_start) < as_epoch_seconds($now_timestring))  {
        		        # Current show
				$program_timing = 1;
		        } else {
              		  	# Future show
				$program_timing = 2;
			}
			$bgcolor = $color_show[$program_timing];
			if($rtvaccess) {
				$program_icon = getScheduleDetails( $program_id , $program_timing );
			}
			if (length($bgcolor) > 0) {
				$bgcolor = " bgcolor=\"$bgcolor\"";
			}
	
			if( $dsp_string ne $previous_date ) {
				if (!$showpdaformat) {
					if ($records == 1) {
						print "<table border=1>";
					}
					print "<tr><td width=10% align=center bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" size=2 color=\"$color_headingtext\"><B>$dsp_string</B></font>\n";
					print "<td width=\"10%\" align=center bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" color=\"$color_headingtext\">Channel</font>";
					print "<td width=\"70%\" align=left bgcolor=\"$color_headingbackground\"><font face=\"$font_heading\" color=\"$color_headingtext\">Title</font>";
					print "</tr>";
				} else {
					print "<p>$dsp_string<p>\n";
				}
				$previous_date = $dsp_string;
			}

			if (!$showpdaformat) {
				print "<tr>";
				print "<td align=left valign=top $bgcolor><font size=2 face=\"$font_listings\">";
			}else{
				print "<$size_pdalistings>";
			}

			$url_parms = "";
			addParameter("STARTDATE",$program_startdate);
			addParameter("STARTHOUR",$program_starthour);
			addParameter("SHOWHOURS",$inp_showhours);
			addParameter("SHOWSLOTS",$inp_showslots);
			addParameter("SHOWPDAFORMAT",$showpdaformat);


			print "<a href=\"$scriptdir/$scriptname$url_parms\">";
			print as_hhmm(as_epoch_seconds($program_true_start));
			print "</a>\n";

			if (!$showpdaformat) {
				print "<td align=left valign=top $bgcolor><font size=2 face=\"$font_listings\">";
			}else{
				print " ";
			} 


			#--------------------------------------------------------------------
			# Add a link to show just the single channel with 2 days of listings
			#-------------------------------------------------------------------

			$url_parms = "";
			addParameter("FIRSTTUNE",$program_tuning);
			addParameter("LASTTUNE",$program_tuning);
			addParameter("STARTDATE",$program_startdate);
			addParameter("STARTHOUR",$program_starthour);
			addParameter("SHOWHOURS","48");
			addParameter("SHOWSLOTS",$inp_showslots);
			addParameter("SHOWPDAFORMAT",$showpdaformat);		

			print "$program_tuning (<a href=\"$scriptdir/$scriptname$url_parms\">$program_channel</a>)\n";

			#-----------------------------------------------------------------------------
			# Force some variables so the odd start times aren't duplicated in the render
			#-----------------------------------------------------------------------------

			$starttime = $program_true_start;
			$colpos = 1;
			$colspan = 1;
			$shortslot = 0;
			#$showrtvtext = 1;

			&RenderShow;

			if (!$showpdaformat) {
				print "</tr>\n";
			}else{
				print "<p>\n";
			}
		}
	}else{
	}

	print "</table><p>";

	if ($records) {
			writeDebug("dotodo::ToDo List Returned $records Rows");
			print "<p><font face=\"$font_menu\">Found $records title(s) matching \"$label\"<p></font>";
	}else{
			writeDebug("dotodo::ToDo List Did Not Return Any Rows");
			print "<p><font face=\"$font_menu\">Did not find any matches for \"$label\".<p></font>";
	}

	endDSN($sth,$db_handle);
	undef $db_handle;


	return 1;

}


#----------------------------------------------------
sub scheduleManualRecording {

	my $unitid = int shift;

	if (countArray($schedulinglist,";") == 1) {
		$inp_selectedrtv = $schedulinglist;
	}

	#------------------------------------------------------------------------
	# First Pass
	#------------------------------------------------------------------------

	if (!$inp_recordtype) {

		$url_parms = "";

		print "\n<form method=POST action=\"$scriptdir/$scriptname$url_parms\">\n";
		print "<table>\n";
		print "<input type=hidden name=ISMANUAL value=\"1\">\n";
		print "<input type=hidden name=MANUALREC value=\"1\">";
		print "<input type=hidden name=STARTDATE value=\"$inp_startdate\">";
		print "<input type=hidden name=STARTHOUR value=\"$inp_starthour\">";
		print "<input type=hidden name=SHOWHOURS value=\"$inp_showhours\">";
		print "<input type=hidden name=SHOWSLOTS value=\"$inp_showslots\">";
		print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";

		if (length($inp_search) > 0) {
			print "<input type=hidden name=SEARCH value=\"$inp_search\">";
		}
		if ($unitid == 0) {
			$unitid = $rtvunit{$defaultreplaytv};
		}

		if (length($inp_selectedrtv) < 1) {
			print "<tr>\n";
			print "<td align=right><B>ReplayTV:</B></td>\n";
			print "<td><select size=\"1\" name=\"SELECTEDRTV\">\n";

			for ( split /;/, $schedulinglist ) {
				/;/;
				if ($_ eq $unitid) {
					print "<option value=\"$_\" selected>$rtvlabel{$_}</option>\n";
				}else{
					print "<option value=\"$_\">$rtvlabel{$_}</option>\n";
				}
			}
			print "</select></td></tr>\n";
		}else{
			print "<tr><td align=right><B>ReplayTV:</B></td><td>";
			print $rtvlabel{$inp_selectedrtv};
			print " ($rtvaddress{$inp_selectedrtv})";
			print "</td></tr>\n";

			print "<input type=hidden name=\"SELECTEDRTV\" value=\"$inp_selectedrtv\">\n";
		}

		print "<tr><td align=right><B>Manual:</B></td>\n";
		print "<td>";
		print "<select size=\"1\" name=\"RECORDTYPE\">\n";
		print "<option value=\"3\">Single Recording</option>\n";
		print "<option value=\"1\">Repeat Recording</option>\n";
		print "</select>\n";
		print "</td></tr>";

		#-----------------------------------------------------------------------
		# While the protocol has all the stuff for different inputsources it
		# does not seem to work.   So this is disabled for now and it will
		# force the tuner.
		#-----------------------------------------------------------------------

		print "<input type=hidden name=\"INPUTSOURCE\" value=\"3\">";

#		print "<tr>\n";
#		print "<td align=right><B>Input:</B></td>\n";
#		print "<td>\n";	
#		print "<select size=\"1\" name=\"INPUTSOURCE\">\n";
#		print "<option value=\"0\">Direct RF</option>\n";
#		print "<option value=\"1\">Line 1</option>\n";
#		print "<option value=\"2\">Line 2</option>\n";
#		print "<option value=\"3\" selected>ReplayTV Tuner</option>\n";
#		print "</select>\n";
#		print "</td></tr>\n";

		print "</table>\n";
	
		if (length($icon_select) > 0) {
			print "<input type=image src=\"$imagedir/$icon_select\" ALT=\"Select\">\n";
		}else{
			print "<input type=submit value=\"Select\" name=\"SUBMITSEL\">\n";
		}

		print "</form><p>\n";

		return 1;
	}

	#------------------------------------------------------------------------
	# Second Pass
	#------------------------------------------------------------------------

	$url_parms = "";
	addParameter("state","slotrequest");
	print "<form method=POST action=$scriptdir/$schedulename$url_parms>\n";
	print "<input type=\"hidden\" name=\"ISMANUAL\" value=\"1\">\n";
	print "<input type=\"hidden\" name=\"INPUTSOURCE\" value=\"$inp_inputsource\">\n";
	if ($rtvport{$inp_selectedrtv} != 80) {
		print "<input type=\"hidden\" name=\"REPLAYTV\" value=\"$rtvaddress{$inp_selectedrtv}:$rtvport{$inp_selectedrtv}\">\n";
	}else{
		print "<input type=\"hidden\" name=\"REPLAYTV\" value=\"$rtvaddress{$inp_selectedrtv}\">\n";
	}
	print "<input type=\"hidden\" name=\"RECORDTYPE\" value=\"$inp_recordtype\">\n";

	(my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime(time); 

	$year += 1900; 
	$mon++;


	#------------------------------------------------------------------------
	# Show Current Data
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<table>\n";
		print "<tr><td align=right>";
	}else{
		print "</CENTER>";
	}

	print "<B>ReplayTV:</B>";
	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}
	print $rtvlabel{$inp_selectedrtv};
	print " ($rtvaddress{$inp_selectedrtv})";
	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<p>";
	}

	print "\n";

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Manual:</B>";

	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}

	if ($inp_recordtype == 1) {
		print "Repeat Recording";
	}

	if ($inp_recordtype == 3) {
		print "Single Recording";
	}

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<p>";
	}
	print "\n";

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Input:</B>";
	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}
	if ($inp_inputsource == 0) {
		print "Direct RF";
	}
	if ($inp_inputsource == 1) {
		print "Line 1";
	}
	if ($inp_inputsource == 2) {
		print "Line 2";
	}
	if ($inp_inputsource == 3) {
		print "ReplayTV Tuner";
	}

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<p>";
	}


	if ($inp_recordtype == 1) {
		
		#----------------------------------------------------------------
		# REPEATING
		#----------------------------------------------------------------
		# Days, Time, Channel/Input, Keep/Quality/(Keep Until), Category
		#----------------------------------------------------------------

		print "<input type=\"hidden\" name=\"RECURRING\" value=\"1\">\n";

		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}

		print "<B>Record on:</B>";

		if (!$showpdaformat) {
			print "</td>\n<td>";
		}else{
			print "<br>";
		}

		print "<input type=checkbox name=\"SUN\" value=\"1\" checked> Sun.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"MON\" value=\"1\" checked> Mon.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"TUE\" value=\"1\" checked> Tue.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"WED\" value=\"1\" checked> Wed.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"THU\" value=\"1\" checked> Thu.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"FRI\" value=\"1\" checked> Fri.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		print "<input type=checkbox name=\"SAT\" value=\"1\" checked> Sat.\n";
		if ($showpdaformat) {
			print "<br>&nbsp;";
		}

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}

		print "\n";

	}

	if ($inp_recordtype == 3) {
		#----------------------------------------------------------------
		# SINGLE
		#----------------------------------------------------------------
		# Date, Time, Channel/Input, Quality/Keep Until/Category
		#----------------------------------------------------------------

		print "<input type=\"hidden\" name=\"RECURRING\" value=\"0\">\n";

		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}

		print "<B>Date:</B>";

		if (!$showpdaformat) {
			print "</td>\n<td>";
		}else{
			print "<br>";
		}

		print "<select size=\"1\" name=\"MONTH\">\n";
		selectMonth($mon);
		print "</select>\n";
	
		print "<select size=\"1\" name=\"DAY\">\n";
		selectDay($mday,31);
		print "</select>\n";

		print "<select size=\"1\" name=\"YEAR\">\n";
		selectYear($year,$year+2);
		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}
	
		print "\n";

	}

	#------------------------------------------------------------------------
	# Time of Recording
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Time:</B>";

	if (!$showpdaformat) {
		print "</td>\n<td>";
	}else{
		print "<br>";
	}

	print "<select size=\"1\" name=\"HOUR\">\n";
	selectNumbers($hour,24,0);
	print "</select>\n";
	print ":";
	print "<select size=\"1\" name=\"MINUTE\">\n";
	print "<option value=\"0\">00</option>\n";
	print "<option value=\"5\">05</option>\n";
	print "<option value=\"15\">15</option>\n";
	print "<option value=\"30\">30</option>\n";
	print "<option value=\"45\">45</option>\n";
	print "<option value=\"55\">55</option>\n";
	print "</select>\n";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}
	
	print "\n";
	
	#------------------------------------------------------------------------
	# Length of Recording
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Record for</B>";

	if (!$showpdaformat) {
		print "</td>\n<td>";
	}else{
		print "<br>";
	}

	print "<select size=\"1\" name=\"LENGTH\">\n";
	print "<option value=\"15\">15 Minutes</option>\n";
	print "<option value=\"30\" selected>30 Minutes</option>\n";
	print "<option value=\"45\">45 Minutes</option>\n";
	print "<option value=\"60\">60 Minutes</option>\n";
	print "<option value=\"75\">75 Minutes</option>\n";
	print "<option value=\"90\">90 Minutes</option>\n";
	print "<option value=\"120\">2 Hours</option>\n";
	print "<option value=\"180\">3 Hours</option>\n";
	print "<option value=\"240\">4 Hours</option>\n";
	print "</select>\n";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}
	
	print "\n";

	#------------------------------------------------------------------------
	# Select Tuning/Input
	#------------------------------------------------------------------------

	if ($inp_inputsource < 3) {

		#----------------------------------------------------------------
		# Input Source: ANT/CATV, Line 1, Line 2
		# Channel: No Tuning, Tune to #0000
		#----------------------------------------------------------------

		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}

		print "<B>Tuning:</B>";

		if (!$showpdaformat) {
			print "</td>\n<td>";
		}else{
			print "<br>";
		}

		print "<input type=\"text\" size=\"4\" name=\"TUNING\" value=\"\">";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}
	
		print "\n";
		
	}else{

		#----------------------------------------------------------------
		# List Channels
		# NOTE: Need to tag with (Cable) (DBS) or (Air) in the 
		# slotrequest - eg BBCA(Cable)
		#----------------------------------------------------------------
	
		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}

		print "<B>Channel:</B>";

		if (!$showpdaformat) {
			print "</td>\n<td>";
		}else{
			print "<br>";
		}

		print "<select size=\"1\" name=\"CHANNEL\">\n";

		my $Stmt = "";
		$Stmt .= "SELECT * ";
		$Stmt .= "FROM $db_table_channels ";
		$Stmt .= "WHERE hidden = 0 ";
		$Stmt .= "ORDER BY display;";

		my $db_handle = &StartDSN;

		my $sth = sqlStmt($db_handle,$Stmt);
		if ( $sth ) {

			while ( $row = $sth->fetchrow_hashref ) {
				my $channel_label = convertfromhtml($row->{'display'});
				my $callsign = $row->{'channel'};
				my $systemtype = $row->{'systemtype'};
				my $lineup = $row->{'lineupname'};
				my $displaynumber = $row->{'displaynumber'};
				my $tuning = $row->{'tuning'};

				print "<option value=\"$callsign($systemtype)\">";
				if (!$showpdaformat) {
					print "$channel_label ($lineup: $displaynumber)";
				}else{
					print "$channel_label ($lineup: $displaynumber)";
				}
				print "</option>\n";
			}

		}else{
			abend("Couldn't get channels");
		}

		endDSN($sth,$db_handle);
		undef $db_handle;

		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}
	
		print "\n";

	}


	#------------------------------------------------------------------------
	# Category
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<tr><td align=right>";
	}

	print "<B>Store in category:</B>";

	if (!$showpdaformat) {
		print "</td><td>";
	}else{
		print " ";
	}

	print "<select size=\"1\" name=\"CATEGORY\">";
	print "<option value=\"255\" selected>All Shows</option>\n";

	$ctr = 0;

	if (countArray($categories{$inp_selectedrtv},";")) {
		for ( split /;/, $categories{$inp_selectedrtv} ) {
			/;/;
			($cat_num,$cat_label) = split(',', $_, 2);
			print "<option value=\"$cat_num\">$cat_label</option>\n";	
			$ctr++;
		}
	}
	print "</select>";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}

	print "\n";

	if ($inp_recordtype == 3) {
		#------------------------------------------------------------------------
		# Keep Until (This Show Only)
		#------------------------------------------------------------------------

		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}
		print "<B>Keep Until:</B>";
		
		if (!$showpdaformat) {
			print "</td>";
		}else{
			print " ";
		}
		print "\n";

		if (!$showpdaformat) {
			print "<td>";
		}
		print "<select size=\"1\" name=\"GUARANTEED\">\n";
		print "<option value=\"1\">I delete</option>\n";
		print "<option value=\"0\">Space needed</option>\n";
		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}

		print "\n";

		print "<input type=\"hidden\" name=\"KEEP\" value=\"1\">\n";
	}else{
		#------------------------------------------------------------------------
		# Episodes to Keep
		#------------------------------------------------------------------------

		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}
		print "<B>Episodes to Keep:</B>";

		if (!$showpdaformat) {
			print "</td>";
		}else{
			print " ";
		}

		print "\n";

		if (!$showpdaformat) {
			print "<td>";
		}

		print "<select size=\"1\" name=\"KEEP\">";
		selectNumbers($rtvdefaultkeep{$inp_selectedrtv},10,1);
		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}
		print "\n";

		#------------------------------------------------------------------------
		# Delete oldest
		#------------------------------------------------------------------------


		if (!$showpdaformat) {
			print "<tr><td align=right>";
		}
		print "<B>Delete oldest:</B>";

		if (!$showpdaformat) {
			print "</td>";
		}else{
			print " ";
		}
		print "\n";


		if (!$showpdaformat) {
			print "<td>";
		}
		print "<select size=\"1\" name=\"GUARANTEED\">\n";
		print "<option value=\"1\">Only for new episode</option>\n";
		print "<option value=\"0\">If space needed</option>\n";
		print "</select>\n";

		if (!$showpdaformat) {
			print "</td></tr>";
		}else{
			print "<br>";
		}

		print "\n";
	}

	#------------------------------------------------------------------------
	# Quality
	#------------------------------------------------------------------------

	if (!$showpdaformat) {
		print "<tr>\n";
		print "<td align=right>";
	}

	print "<B>Quality:</B>";

	if (!$showpdaformat) {
		print "</td>";
	}else{
		print " ";
	}
	print "\n";

	if (!$showpdaformat) {
		print "<td>";	
	}
	print "\n";

	print "<select size=\"1\" name=\"QUALITY\">\n";
	if ($rtvdefaultquality{$inp_selectedrtv} == 2) {
		print "<option value=\"2\" selected>Standard</option>\n";
	}else{
		print "<option value=\"2\">Standard</option>\n";
	}
	if ($rtvdefaultquality{$inp_selectedrtv} == 1) {
		print "<option value=\"1\" selected>Medium</option>\n";
	}else{
		print "<option value=\"1\">Medium</option>\n";
	}
	if ($rtvdefaultquality{$inp_selectedrtv} == 0) {
		print "<option value=\"0\" selected>High</option>\n";
	}else{
		print "<option value=\"0\">High</option>\n";
	}
	print "</select>\n";

	if (!$showpdaformat) {
		print "</td></tr>";
	}else{
		print "<br>";
	}
	print "\n";


	if (!$showpdaformat) {
		print "\n<tr><td></td><td>";
	}else{
		print "<p>\n";
	}

	#------------------------------------------------------------------------
	# Set Up Return Paths and Show Button
	#------------------------------------------------------------------------

	$url_parms = "";
	addParameter("STARTDATE",$inp_startdate);
	addParameter("STARTHOUR",$inp_starthour);
	addParameter("SHOWHOURS",$inp_showhours);
	addParameter("SHOWSLOTS",$inp_showslots);
	addParameter("SHOWPDAFORMAT",$showpdaformat);

	writeDebug("scheduleManualRecording::ReturnPath: $scriptdir/$scriptname$url_parms");
	print "\n<input type=hidden name=RETURNURL value=\"$scriptdir/$scriptname$url_parms\">\n";
	print "\n<input type=hidden name=RETURNTEXT value=\"Back to Schedule\">\n";

	if (length($icon_schedule) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_schedule\" ALT=\"Schedule\">\n";
	}else{
		print "\n<input type=submit value=Schedule name=SUBMIT>\n";
	}
	print "</form><p>";

	if (!$showpdaformat) {
		print "</td></tr>\n</table>";
	}

	return 1;
}

#----------------------------------------------------
sub editRTVChannel($) {
# ****** NOT IMPLEMENTED ****************************
	return 0;
}

#----------------------------------------------------
sub deleteRTVShow($) {
# ****** NOT IMPLEMENTED ****************************


	if (!$rtv_allowdelete) {
		return 0;
	}

	return 0;
}



#----------------------------------------------------
sub showDetail($) {
	#
	# Show detail for a ReplayShow and allow some actions
	#
	# Parameter is 
	#
	#
	#------------------------------------------------------------------------------

	my $specialdebug = 0;
	my $rtvshow = shift;

	print "<$size_title>ReplayShow Detail</$size_title><p>";

	if ($specialdebug) {
		writeDebug("showdetail::starting($rtvshow)");
	}

	if ($rtvshow eq $null) {
		writeDebug("showdetail::no show, no go");
		return 0;
	}

	#---------------------------------------------------------------------
	# Permission Check
	#---------------------------------------------------------------------

	if (!$rtvaccess) {
		writeDebug("showdetail::exiting(no rtv access)");
		return 0;
	}


	#---------------------------------------------------------------------
	# Load the module with ReplayTV functions
	#---------------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("showdetail::loading module rg_replay.pl");
	}

	require 'rg_replay.pl';
	identifyLoadedModules("rg_replay.pl");

	if ($specialdebug) {
		writeDebug("showdetail::loaded module rg_replay.pl");
	}

	$rtvshow = decodehex($rtvshow);
	if ($specialdebug) {
		writeDebug("showdetail::decoded: $rtvshow");
	}

	undef $show_rtvcc;	
	undef $show_rtvstereo;	
	undef $show_rtvrepeat;	
	undef $show_rtvsap;	
	undef $show_rtvlbx;	
	undef $show_rtvmovie;
	undef $show_rtvrating;
	($show_replayid,$chan_showlabel,$show_rtvtitle,$show_rtvrecorded,$show_rtvepisode,$show_rtvdescription,$show_rtvminutes,$show_inputsource,$show_quality,$chan_rtvcreate,$chan_daysofweek,$chan_beforepadding,$chan_afterpadding,$show_beforepadding,$show_afterpadding,$chan_themeflags,$chan_themestring,$chan_thememinutes,$chan_channeltype,$chan_guaranteed,$show_channelname,$show_channellabel,$show_tuning,$show_rtvcc,$show_rtvstereo,$show_rtvrepeat,$show_rtvsap,$show_rtvlbx,$show_rtvmovie,$show_rtvrating,$show_category,$chan_keep,$chan_norepeats,$chan_minutes) = split(/\|/,$rtvshow);

	if ($specialdebug) {
		writeDebug("showdetail::$show_replayid,$chan_showlabel,$show_rtvtitle,$show_rtvrecorded,$show_rtvepisode,$show_rtvdescription,$show_rtvminutes,$show_inputsource,$show_quality,$chan_rtvcreate,$chan_daysofweek,$chan_beforepadding,$chan_afterpadding,$show_beforepadding,$show_afterpadding,$chan_themeflags,$chan_themestring,$chan_thememinutes,$chan_channeltype,$chan_guaranteed,$show_channelname,$show_channellabel,$show_tuning,$show_rtvcc,$show_rtvstereo,$show_rtvrepeat,$show_rtvsap,$show_rtvlbx,$show_rtvmovie,$show_rtvrating,$show_category,$chan_keep,$chan_norepeats,$chan_minutes");
	}


	#-------------------------------------
	# Channel Stuff
	#-------------------------------------

	print "<font size=+1><B>$chan_showlabel</B></font><br>";
	print "($show_category)<p>";

	my $chan_reservedtime = 0;

	#----------------			
	# First Row
	#----------------

	if ($chan_channeltype == 1) {
		print "Keep $chan_keep ";
		if ($chan_keep > 1) {
			print "episodes";
		}else{
			print "episode";
		}
		print "; ";
		$chan_reservedtime = ( $chan_minutes + $chan_beforepadding + $chan_afterpadding ) * $chan_keep;
		$chan_reservedtime = getRunningTime($chan_reservedtime,1);
		print "$chan_reservedtime ";
		if ($chan_guaranteed) {
			print "reserved ";
		}
		print "at " . lc $qualitylabel[$show_quality] . " quality.<p>";
	}

	if (($chan_channeltype == 2) || ($chan_channeltype == 4)) {
		$chan_reservedtime = getRunningTime($chan_thememinutes,1);
		print "$chan_reservedtime ";
		print "at " . lc $qualitylabel[$show_quality] . " quality.<p>";
	}

	if ($chan_channeltype == 3) {
		$chan_reservedtime = $show_rtvminutes + $show_beforepadding + $show_afterpadding;
		$chan_reservedtime = getRunningTime($chan_reservedtime,1);
		print "Keep until I delete; $chan_reservedtime reserved ";
		print "at " . lc $qualitylabel[$show_quality] . " quality.<p>";
	}

	#---------------
	# Second Row
	#---------------

	print "This Replay Channel ";
	
	if ($chan_channeltype == 1) {
		print "will record ";
		if ($chan_norepeats) {
			print "only new";
		}else{
			print "all";
		}
		print " episodes of $show_rtvtitle occuring ";
	
		my $days = "";
		my $flag = 0;
		my $group = 0;

		if ($chan_daysofweek == 1) {
			$days = "every Sunday";
		}

		if ($chan_daysofweek == 2) {
			$days = "every Monday";
		}

		if ($chan_daysofweek == 4) {
			$days = "every Tuesday";
		}

		if ($chan_daysofweek == 8) {
			$days = "every Wednesday";
		}

		if ($chan_daysofweek == 16) {
			$days = "every Thursday";
		}

		if ($chan_daysofweek == 32) {
			$days = "every Friday";
		}

		if ($chan_daysofweek == 64) {
			$days = "every Saturday";
		}

		if ($chan_daysofweek == 127) {
			$days = "any day";
		}	

		if ($days eq $null) {
			$days = "every ";

			if ($chan_daysof_week & 1) {
				if ($flag) {
					$days .= ", ";
					$flag = 0;
				}
				$flag = 1;
				$days .= "Sun";
			}

			if ($chan_daysof_week & 2) {
				if ($flag) {
					$days .= ", ";
					$flag = 0;
				}
				$flag = 1;
				$days .= "Mon";
			}
						

			if ($chan_daysof_week & 4) {
				if ($flag) {
					$days .= ", ";
					$flag = 0;
				}
				$flag = 1;
				$days .= "Tue";
			}
				

			if ($chan_daysof_week & 8) {
				if ($flag) {
					$days .= ", ";
					$flag = 0;
				}
				$flag = 1;
				$days .= "Wed";
			}
						

			if ($chan_daysof_week & 16) {
				if ($flag) {
					$days .= ", ";
					$flag = 0;
				}
				$flag = 1;
				$days .= "Thu";
			}
						

			if ($chan_daysof_week & 32) {
				if ($flag) {
					$days .= ", ";
					$flag = 0;
				}
				$flag = 1;
				$days .= "Fri";
			}
		

			if ($chan_daysof_week & 64) {
				if ($flag) {
					$days .= ", ";
					$flag = 0;
				}
				$flag = 1;
				$days .= "Sat";
			}

		}			

		$show_rtvrecorded_local = as_time_string($show_rtvrecorded+5);
		$dsp_string =  as_hhmm(as_epoch_seconds($show_rtvrecorded_local));
		$dsp_string .= " - " .  as_hhmm(as_epoch_seconds($show_rtvrecorded_local) + ($show_rtvminutes+$show_beforepadding+$show_afterpadding) * 60);
		
		print "$days from $dsp_string on channel $show_tuning ($show_channelname).<br>";
	}

	if (($chan_channeltype == 2) || ($chan_channeltype == 4)) {
		print " will record shows on any channel with the title: \"$chan_themestring\"<br>";
	}
		

	if ($chan_channeltype == 3) {
		$show_rtvrecorded_local = as_time_string($show_rtvrecorded+5);
		$rng_string = substr($show_rtvrecorded_local,0,8);
		$wday = strftime( "%A", localtime($show_rtvrecorded));
		$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2);

		$dsp_string .= " from " . as_hhmm(as_epoch_seconds($show_rtvrecorded_local));
		$dsp_string .= " - " .  as_hhmm(as_epoch_seconds($show_rtvrecorded_local) + ($show_rtvminutes+$show_beforepadding+$show_afterpadding) * 60);

		print "recorded $show_rtvtitle on $dsp_string on channel $show_tuning ($show_channelname).";
	}

	print "<p>";

	#-------------------------------------
	# Show Stuff
	#-------------------------------------


	if (length($show_rtvepisode) > 0) {
		if ($show_rtvtitle ne $show_rtvepisode) {
			print "<B>$show_rtvtitle</B>: ";
		}
		print "<B>$show_rtvepisode</B>";
	}else{
		print "<B>$show_rtvtitle</B>";
	}
		
	my $show_rtvrecorded_local = as_time_string($show_rtvrecorded+5);
	my $rng_string = substr($show_rtvrecorded_local,0,8);
	my $wday = strftime( "%A", localtime($show_rtvrecorded));
	my$dsp_string = substr($rng_string,4,2) . "/" . substr($rng_string,6,2);  # . "/" . substr($rng_string,0,4);

	my $dsp_string .= " at " . as_hhmm(as_epoch_seconds($show_rtvrecorded_local));

	print "<br>";
	
	print getRunningTime($show_rtvminutes+$show_beforepadding+$show_afterpadding,1);

	print "; recorded $dsp_string from $show_tuning ($show_channelname)<br>";

	my $flag = 0;

	$dsp_string = "";

	if (length($show_rtvmovie) > 0) {
		$dsp_string .= $show_rtvmovie;
		$show_rtvrating = "";
		$flag = 1;
	}


	if (length($show_rtvcc) > 0) {
#		if ($flag) {
#			$dsp_string .= ", ";
#			$flag = 0;
#		}
#		$dsp_string .= $show_rtvcc;
#		$flag = 1;
	}

	if (length($show_rtvstereo) > 0) {
#		if ($flag) {
#			$dsp_string .= ", ";
#			$flag = 0;
#		}
#		$dsp_string .=  $show_rtvstereo;
#		$flag = 1;
	}		

	if (length($show_rtvrating) > 0) {
		if ($flag) {
				$dsp_string .=  ", ";
			$flag = 0;
		}
		$dsp_string .=  $show_rtvrating;
		$flag = 1;
	}



	if (length($show_rtvrepeat) > 0) {
		if ($flag) {
			$dsp_string .=  ", ";
			$flag = 0;
		}
		$dsp_string .=  $show_rtvrepeat;
		$flag = 1;
	}

	if (length($show_rtvlbx) > 0) {
		if ($flag) {
			$dsp_string .=  ", ";
			$flag = 0;
		}
		$dsp_string .=  $show_rtvlbx;
		$flag = 1;
	}


	if ($flag) {
		$flag = 0;
	}

	if (length($dsp_string) > 0) {
		print "($dsp_string) ";
	}

	if (length($show_rtvepisode) > 0) {
		print "$show_rtvepisode: ";
	}

	if (length($show_rtvdescription) > 0) {
		print "$show_rtvdescription";
	}


	print "<br>\n";


	# Buttons to do things (Find All Episodes,Find Repeat) and eventually "Delete"

	print "<p><CENTER>\n";
	print "<table border=0><tr>";

	print "<td>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=SEARCH value=\"$chan_showlabel\">\n";
	if (length($icon_findall) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_findall\" ALT=\"Find All\">\n";
	}else{
		print "<input type=submit value=\"Find All\" name=\"FIND\">\n";
	}
	print "</form>\n";
	print "<td>";
	

	print "<td>";
	print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
	print "<input type=hidden name=\"SHOWPDAFORMAT\" value=\"$showpdaformat\">\n";
	print "<input type=hidden name=SEARCH value=\"$chan_showlabel|$show_rtvepisode\">\n";
	print "<input type=hidden name=FIELD value=\"title,subtitle\">\n";
	if (length($icon_findrepeat) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_findrepeat\" ALT=\"Find Repeats\">\n";
	}else{
		print "<input type=submit value=\"Find Repeats\" name=\"FINDREPEATS\">\n";
	}
	print "</form>\n";

	if ($rtv_allowdelete) {
		print "<td>";
	
		print "<form method=POST action=\"$scriptdir/$scriptname\">\n";
		print "<input type=hidden name=SHOWPDAFORMAT value=\"$showpdaformat\">\n";
		print "<input type=hidden name=DELETESHOW value=\"" . converttext($rtvshow,length($rtvshow)) . "\">";
		if (length($icon_delete) > 0) {
			print "\n<input type=image src=\"$imagedir/$icon_delete\" ALT=\"Delete\">\n";
		}else{
			print "<input type=submit value=\"Delete\" name=\"DELETE\">\n";
		}
		print "</form>";
	}

	print "</table>\n";

	if ($specialdebug) {
		writeDebug("showdetail::exiting");
	}

	return 1;
	
}


#----------------------------------------------------
sub showRTVShows($) {
	#
	# Show ReplayGuide equiv for the given RTV(s)
	#
	# Parameter is a comma delimited list of ReplayID(s).  The keyword "ALL" can be
	# used for all units defined in Personal ReplayGuide.   If no parameter is
	# present all is assumed.
	#
	# NOTE: $replaylist must already be parsed and $rtvaccess must be nonzero or
	#	the function will fail.
	#
	#------------------------------------------------------------------------------

	#---------------------------------------------------------------------
	# Set defaults
	#---------------------------------------------------------------------

	my $specialdebug = 0;
	my $rtvlist = shift;
	my $prev_channel = "";
	my $prev_id = "";

	print "<$size_title>ReplayShows</$size_title><p>";

	if ($specialdebug) {
		writeDebug("showrtvshows::starting($rtvlist)");
	}

	if (($rtvlist eq $null) || ($rtvlist eq "0")) {
		$rtvlist = "ALL";
	}

	if ($rtvlist eq "ALL") {
		$rtvlist = $replaylist;
	}

	#---------------------------------------------------------------------
	# Sanity check
	#---------------------------------------------------------------------

	if ($replaylist eq $null) {
		writeDebug("showrtvshows::exiting(no units defined)");
		return 0;
	}

	if ($rtvlist eq $null) {
		writeDebug("showrtvshows::exiting(nothing to do)");
		return 0;
	}

	#---------------------------------------------------------------------
	# Permission Check
	#---------------------------------------------------------------------

	if (!$rtvaccess) {
		writeDebug("showrtvshows::exiting(no rtv access)");
		return 0;
	}


	#---------------------------------------------------------------------
	# Load the module with ReplayTV functions
	#---------------------------------------------------------------------


	if ($specialdebug) {
		writeDebug("showrtvshows::loading module rg_replay.pl");
	}

	require 'rg_replay.pl';
	identifyLoadedModules("rg_replay.pl");

	if ($specialdebug) {
		writeDebug("showrtvshows::loaded module rg_replay.pl");
	}

	#---------------------------------------------------------------------
	# Gather ReplayChannels
	#---------------------------------------------------------------------


	if ($specialdebug) {
		writeDebug("showrtvshows::getting replaychannels");
	}

	my $rtvchannelcount = collectRTVChannels($rtvlist);

	if ($specialdebug) {
		writeDebug("showrtvshows::found $rtvchannelcount replaychannels");
	}

	#---------------------------------------------------------------------
	# Gather ReplayShows
	#---------------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("showrtvshows::getting replayshows");
	}

	my $rtvshowcount = collectRTVShows($rtvlist);


	if ($specialdebug) {
		writeDebug("showrtvshows::found $rtvshowcount replayshows");
	}

	#---------------------------------------------------------------------
	# If either are 0, something is bad and we need to bail
	#---------------------------------------------------------------------

	if (($rtvshowcount == 0) || ($rtvchannelcount == 0)) {
		writeDebug("showrtvshows::exiting(could not find any channels or shows for \"$rtvlist\")");
		return 0;
	}

	#---------------------------------------------------------------------
	# Merge the ReplayChannel/Show data into a new structure for optimal
	# sorting.
	#---------------------------------------------------------------------

	if ($specialdebug) {
		writeDebug("showrtvshows::processing shows and channels");
	}


	my $ctr = 0;

	do {
		$ctr++;
		if ($specialdebug) {
			writeDebug("showrtvshows::processing $ctr of $rtvshowcount");
		}
		my $retcode = getShowAndParent($rtvshows[$ctr]);
		if ($specialdebug) {
			writeDebug("showrtvshows::getShowAndParent returned $retcode");
		}
		$rtventry[$ctr] = "$show_replayid|$chan_showlabel|$show_rtvtitle|$show_rtvrecorded|$show_rtvepisode|$show_rtvdescription|$show_rtvminutes|$show_inputsource|$show_quality|$chan_rtvcreate|$chan_daysofweek|$chan_beforepadding|$chan_afterpadding|$show_beforepadding|$show_afterpadding|$chan_themeflags|$chan_themestring|$chan_thememinutes|$chan_channeltype|$chan_guaranteed|$show_channelname|$show_channellabel|$show_tuning|$show_rtvcc|$show_rtvstereo|$show_rtvrepeat|$show_rtvsap|$show_rtvlbx|$show_rtvmovie|$show_rating|$show_category|$chan_keep|$chan_norepeats|$chan_minutes";
		if ($specialdebug) {
			writeDebug("showrtvshows::rtventry[$ctr]: $rtventry[$ctr]");
		}
	} while $ctr < $rtvshowcount;

	if ($specialdebug) {
		writeDebug("showrtvshows::processed $ctr shows");
	}

	@rtventry = sort @rtventry;

	#---------------------------------------------------------------------
	# Display an anchor menu for jumping to a particular Replay
	#---------------------------------------------------------------------

	print "<center><font size=+2>";

	my $ctr = 0;
	
	for ( split /,/, $replaylist ) {
		/,/;
		$ctr++;
		my $addr = $rtvaddress{$_};
		my $label = $rtvlabel{$_};
		if ($ctr > 1) {
			print " | ";
		}
		print "<a href=\"#$label\">$label</a>";
	}
	print "</font><p>";

	#---------------------------------------------------------------------
	# Display All Recorded Shows from Selected ReplayTV(s)
	#---------------------------------------------------------------------

	print "<table border=1>";

	$ctr = 0;
	my $no_sep_flag = 0;


	do {
		#---------------------------------------------------------------------
		# This will always be sorted by replayid,showtitle,recorddate
		#---------------------------------------------------------------------

		$ctr++;
		if ($specialdebug) {
			writeDebug("showrtvshows::processing $ctr of $rtvshowcount");
		}

		undef $show_rtvcc;	
		undef $show_rtvstereo;	
		undef $show_rtvrepeat;	
		undef $show_rtvsap;	
		undef $show_rtvlbx;	
		undef $show_rtvmovie;
		undef $show_rtvrating;
		($show_replayid,$chan_showlabel,$show_rtvtitle,$show_rtvrecorded,$show_rtvepisode,$show_rtvdescription,$show_rtvminutes,$show_inputsource,$show_quality,$chan_rtvcreate,$chan_daysofweek,$chan_beforepadding,$chan_afterpadding,$show_beforepadding,$show_afterpadding,$chan_themeflags,$chan_themestring,$chan_thememinutes,$chan_channeltype,$chan_guaranteed,$show_channelname,$show_channellabel,$show_tuning,$show_rtvcc,$show_rtvstereo,$show_rtvrepeat,$show_rtvsap,$show_rtvlbx,$show_rtvmovie,$show_rtvrating,$show_category,$chan_keep,$chan_norepeats,$chan_minutes) = split(/\|/,$rtventry[$ctr]);

		if ($specialdebug) {
			writeDebug("showrtvshows::getShowAndParent returned $retcode");
			writeDebug("showrtvshows::rtventry($ctr): $show_replayid,$chan_showlabel,$show_rtvtitle,$show_rtvrecorded,$show_rtvepisode,$show_rtvdescription,$show_rtvminutes,$show_inputsource,$show_quality,$chan_rtvcreate,$chan_daysofweek,$chan_beforepadding,$chan_afterpadding,$show_beforepadding,$show_afterpadding,$chan_themeflags,$chan_themestring,$chan_thememinutes,$chan_channeltype,$chan_guaranteed,$show_channelname,$show_channellabel,$show_tuning,$show_rtvcc,$show_rtvstereo,$show_rtvrepeat,$show_rtvsap,$show_rtvlbx,$show_rtvmovie,$show_rtvrating,$show_category,$chan_keep,$chan_norepeats,$chan_minutes");
		}

		if ($specialdebug) {
			writeDebug("showrtvshows::prev_id: $prev_id show_replayid: $show_replayid");
		}

		#---------------------------------------------------------------------
		# If the ReplayID has changed, make a new anchor and show the label.
		#---------------------------------------------------------------------

		if ($prev_id ne $show_replayid) {
			print "<tr><td colspan=2><$size_title><a name=\"$rtvlabel{$show_replayid}\">$rtvlabel{$show_replayid}</a></$size_title></td></tr>\n";
		}

		if ($specialdebug) {
			writeDebug("showrtvshows::prev_channel: $prev_channel chan_rtvcreate: $chan_rtvcreate");
		}

		#---------------------------------------------------------------------
		# If ReplayChannel ID has changed, start a new row.
		#---------------------------------------------------------------------

		if ($prev_channel ne $chan_rtvcreate) {
			if ($specialdebug) {
				writeDebug("showrtvshows::processing new replayChannel");
				writeDebug("showrtvshows::chan_minutes: $chan_minutes, chan_keep: $chan_keep, chan_beforepadding: $chan_beforepadding, chan_afterpadding: $chan_afterpadding");
			}
			if ($ctr == 1) {
				print "<tr><td align=center valign=center width=25%>";
			}else{
				print "<tr><td align=center valign=center>";
			}
			print "<font size=+1><B>$chan_showlabel</B></font><br>";
			print "($show_category)<p>";

			my $chan_reservedtime = 0;

			#----------------			
			# First Row
			#----------------

			if ($chan_channeltype == 1) {
				print "Keep $chan_keep ";
				if ($chan_keep > 1) {
					print "episodes";
				}else{
					print "episode";
				}
				print "; ";
				$chan_reservedtime = ( $chan_minutes + $chan_beforepadding + $chan_afterpadding ) * $chan_keep;
				$chan_reservedtime = getRunningTime($chan_reservedtime,1);
				print "$chan_reservedtime ";
				if ($chan_guaranteed) {
					print "reserved ";
				}
				print "at " . lc $qualitylabel[$show_quality] . " quality.<p>";
			}

			if (($chan_channeltype == 2) || ($chan_channeltype == 4)) {
				$chan_reservedtime = getRunningTime($chan_thememinutes,1);
				print "$chan_reservedtime ";
				print "at " . lc $qualitylabel[$show_quality] . " quality.<p>";
			}

			if ($chan_channeltype == 3) {
				$chan_reservedtime = $show_rtvminutes + $show_beforepadding + $show_afterpadding;
				$chan_reservedtime = getRunningTime($chan_reservedtime,1);
				print "Keep until I delete; $chan_reservedtime reserved ";
				print "at " . lc $qualitylabel[$show_quality] . " quality.<p>";
			}

			#---------------
			# Second Row
			#---------------

			print "This Replay Channel ";
			
			if ($chan_channeltype == 1) {
				print "will record ";
				if ($chan_norepeats) {
					print "only new";
				}else{
					print "all";
				}
				print " episodes of $show_rtvtitle occuring ";
				
				my $days = "";
				my $flag = 0;
				my $group = 0;

				if ($chan_daysofweek == 1) {
					$days = "every Sunday";
				}

				if ($chan_daysofweek == 2) {
					$days = "every Monday";
				}

				if ($chan_daysofweek == 4) {
					$days = "every Tuesday";
				}

				if ($chan_daysofweek == 8) {
					$days = "every Wednesday";
				}

				if ($chan_daysofweek == 16) {
					$days = "every Thursday";
				}

				if ($chan_daysofweek == 32) {
					$days = "every Friday";
				}

				if ($chan_daysofweek == 64) {
					$days = "every Saturday";
				}

				if ($chan_daysofweek == 127) {
					$days = "any day";
				}	

				if ($days eq $null) {
					$days = "every ";

					if ($chan_daysof_week & 1) {
						if ($flag) {
							$days .= ", ";
							$flag = 0;
						}
						$flag = 1;
						$days .= "Sun";
					}

					if ($chan_daysof_week & 2) {
						if ($flag) {
							$days .= ", ";
							$flag = 0;
						}
						$flag = 1;
						$days .= "Mon";
					}
						

					if ($chan_daysof_week & 4) {
						if ($flag) {
							$days .= ", ";
							$flag = 0;
						}
						$flag = 1;
						$days .= "Tue";
					}
						

					if ($chan_daysof_week & 8) {
						if ($flag) {
							$days .= ", ";
							$flag = 0;
						}
						$flag = 1;
						$days .= "Wed";
					}
						

					if ($chan_daysof_week & 16) {
						if ($flag) {
							$days .= ", ";
							$flag = 0;
						}
						$flag = 1;
						$days .= "Thu";
					}
						

					if ($chan_daysof_week & 32) {
						if ($flag) {
							$days .= ", ";
							$flag = 0;
						}
						$flag = 1;
						$days .= "Fri";
					}
						

					if ($chan_daysof_week & 64) {
						if ($flag) {
							$days .= ", ";
							$flag = 0;
						}
						$flag = 1;
						$days .= "Sat";
					}

				}			
				$show_rtvrecorded_local = as_time_string($show_rtvrecorded+5);
				$dsp_string =  as_hhmm(as_epoch_seconds($show_rtvrecorded_local));
				$dsp_string .= " - " .  as_hhmm(as_epoch_seconds($show_rtvrecorded_local) + ($show_rtvminutes+$show_beforepadding+$show_afterpadding) * 60);
			
				print "$days from $dsp_string on channel $show_tuning ($show_channelname).<br>";
			}

			if (($chan_channeltype == 2) || ($chan_channeltype == 4)) {
				print " will record shows on any channel with the title: \"$chan_themestring\"<br>";
			}
			

			if ($chan_channeltype == 3) {
				$show_rtvrecorded_local = as_time_string($show_rtvrecorded+5);
				$rng_string = substr($show_rtvrecorded_local,0,8);
				$wday = strftime( "%A", localtime($show_rtvrecorded));
				$dsp_string = $wday . ", " . substr($rng_string,4,2) . "/" . substr($rng_string,6,2);

				$dsp_string .= " from " . as_hhmm(as_epoch_seconds($show_rtvrecorded_local));
				$dsp_string .= " - " .  as_hhmm(as_epoch_seconds($show_rtvrecorded_local) + ($show_rtvminutes+$show_beforepadding+$show_afterpadding) * 60);

				print "recorded $show_rtvtitle on $dsp_string on channel $show_tuning ($show_channelname).";
			}
			

			print "<td valign=top align=left>";
			$no_sep_flag = 1;
		}

		#---------------------------------------------------------------------
		# If it's not the first ReplayShow for the Channel, add a horizontal 
		# break
		#---------------------------------------------------------------------
		
		if ($no_sep_flag) {
			$no_sep_flag = 0;
		}else{
			print "<br><hr>";
		}


		#---------------------------------------------------------------------
		# Display Data for the ReplayShow
		#---------------------------------------------------------------------

		$url_parms = "";
		addParameter("STARTDATE",$inp_startdate);
		addParameter("STARTHOUR",$inp_starthour);
		addParameter("SHOWHOURS",$inp_showhours);
		addParameter("SHOWSLOTS",$inp_showslots);
		addParameter("SHOWPDAFORMAT",$showpdaformat);
		addParameter("SHOWDETAIL",converttext($rtventry[$ctr],length($rtventry[$ctr])));

		print "<a href=\"$scriptdir/$scriptname$url_parms\">";

		if (length($show_rtvepisode) > 0) {
			print "<B>$show_rtvepisode</B>";
		}else{
			print "<B>$show_rtvtitle</B>";
		}

		print "</a>";
			
		$show_rtvrecorded_local = as_time_string($show_rtvrecorded+5);
		$rng_string = substr($show_rtvrecorded_local,0,8);
		$wday = strftime( "%A", localtime($show_rtvrecorded));
		$dsp_string = substr($rng_string,4,2) . "/" . substr($rng_string,6,2);  # . "/" . substr($rng_string,0,4);

		$dsp_string .= " at " . as_hhmm(as_epoch_seconds($show_rtvrecorded_local));

		print "<br>";
	
		print getRunningTime($show_rtvminutes+$show_beforepadding+$show_afterpadding,1);

		print "; recorded $dsp_string from $show_tuning ($show_channelname)<br>";

		my $flag = 0;

		$dsp_string = "";

		if (length($show_rtvmovie) > 0) {
			$dsp_string .= $show_rtvmovie;
			$show_rtvrating = "";
			$flag = 1;
		}


		if (length($show_rtvcc) > 0) {
#			if ($flag) {
#				$dsp_string .= ", ";
#				$flag = 0;
#			}
#			$dsp_string .= $show_rtvcc;
#			$flag = 1;
		}

		if (length($show_rtvstereo) > 0) {
#			if ($flag) {
#				$dsp_string .= ", ";
#				$flag = 0;
#			}
#			$dsp_string .=  $show_rtvstereo;
#			$flag = 1;
		}		

		if (length($show_rtvrating) > 0) {
			if ($flag) {
				$dsp_string .=  ", ";
				$flag = 0;
			}
			$dsp_string .=  $show_rtvrating;
			$flag = 1;
		}



		if (length($show_rtvrepeat) > 0) {
			if ($flag) {
				$dsp_string .=  ", ";
				$flag = 0;
			}
			$dsp_string .=  $show_rtvrepeat;
			$flag = 1;
		}

		if (length($show_rtvlbx) > 0) {
			if ($flag) {
				$dsp_string .=  ", ";
				$flag = 0;
			}
			$dsp_string .=  $show_rtvlbx;
			$flag = 1;
		}


		if ($flag) {
			$flag = 0;
		}

		if (length($dsp_string) > 0) {
			print "($dsp_string) ";
		}

		if (length($show_rtvepisode) > 0) {
			print "$show_rtvepisode: ";
		}

		if (length($show_rtvdescription) > 0) {
			print "$show_rtvdescription";
		}


		print "<br>\n";

		$prev_channel = $chan_rtvcreate;
		$prev_id = $show_replayid;

	} while $ctr < $rtvshowcount;

	if ($specialdebug) {
		writeDebug("showrtvshows::done");
	}	

	print "</table>\n";	

	if ($specialdebug) {
		writeDebug("showrtvshows::exiting");
	}

	return 1;
}

#----------------------------------------------------
sub CalculateSlotTimes{
	#
	# Calculate (in epoch seconds) times for the slot based on position
	#
	#---------------------------------------------------------------------------

	$es_slotstart = $es_starttime + ((($colpos - 1) * $inp_showslots) * 60);
	$es_nextslot = $es_starttime + ((($colpos) * $inp_showslots) * 60);
	$es_prevslot = $es_starttime + ((($colpos - 2) * $inp_showslots) * 60);

	return 1;
}



#----------------------------------------------------
sub ReadConfig{
	#
	# Read Configuration File
	#
	# ------------------------------------------------------------------------------

	my $retcode = 0;


	#------------------------------------------------------------------------------
	# Set Defaults
	#------------------------------------------------------------------------------

	$wwwdir = "/";
	$scriptdir = "/scripts";
	$scriptname = "replayguide.pl";
	$schedulename = "schedule.pl";				
	$scheduler = "rg_scheduler.pl";				

	# OS-Sensitive defaults
	if ($^O eq 'MSWin32') {
		$schedule2sql = "schedule2sql.pl";
	} else {
		$schedule2sql = "./schedule2sql.pl";
	}

	$defaultshowslots = 30;
	$defaultshowhours = 3;

	$defaultreplaytv = "";
	$defaultrefreshinterval = -1;
	$rtv_snapshotpath = ".";

	$newwindow = 0;
	$usingapache = 0;
	$showchannelicons = 0;
	$channelicondir = "";
	
	$showheaderrows = 0;
	$searchfutureonly = 0;
	$showbuttonicons = 0;
	$showpdaformat = 0;
	
	$showrtvicons = 1;
	$showrtvtext = 1;
	$showrtvthemes = 1;

	$allowtitleedit = 0;
	$skipversioncheck=  0;
	$showschedulebar = 0;

	$rtv_updatesleepseconds = 0;
	$rtv_allowdelete = 0;

	
	$primetime_start = 20;
	$todooption = 0;	
	$todofromstart = 0;

	$grid_end_overlap = 15;
	$grid_leeway_second = 300;

	# Default show colors: past, present, future
	@color_show = ( "#C0C0C0", "#F0F0F0", "#FFFFFF" );
	@color_scheduled = ( "#A0C0A0", "#B0F0B0", "#D0FFD0" );
	@color_conflict = ( "#C0A0A0", "#F0B0B0", "#FFD0D0" );
	@color_theme = ( "#C0C0CF", "#D0D0DF", "#E0E0FF" );
	@color_theme_conflict = ( "#C0C060", "#F0F090", "#FFFFB0" );
	$color_background = "#FFFFFF";
	$color_text = "#000000";
	$color_visitedlink = "#0000A0";
	$color_activelink = "#0000FF";
	$color_link = "#0000D0";
	$color_channelbackground = "#F0F0F0";
	$color_channeltext = "#000000";
	$color_headingbackground = "#E0E0E0";
	$color_headingtext = "#000000";

	$pda_list = "NONE";
	$allow_list = "ALL";

	$font_title = "Times New Roman";	
	$font_heading = "Times New Roman";
	$font_menu = "Times New Roman";
	$font_listings = "Times New Roman";
	$font_detail = "Times New Roman";
	$font_channel = "Terminal";

	$icon_refresh = "";
	$icon_now = "";
	$icon_go = "";
	$icon_all = "";
	$icon_prevwindow = "";
	$icon_nextwindow = "";
	$icon_prevchan = "";
	$icon_nextchan = "";
	$icon_find = "";
	$icon_select = "";
	$icon_schedule = "";
	$icon_done = "";
	
	$image_stereo = "";
	$image_repeat = "";
	$image_cc = "";

	$image_tvg = "";
	$image_tvpg = "";
	$image_tv14 = "";
	$image_tvy = "";
	$image_tvy7 = "";
	$image_tvma = "";

	$image_mpaag = "";
	$image_mpaapg = "";
	$image_mpaapg13 = "";
	$image_mpaar = "";
	$image_mpaanc17 = "";
	$image_mpaanr = "";

	$default_mode = "now";
		
	#-------------------------------------------------------------------
	# read config
	#-------------------------------------------------------------------

	$retcode = getConfig($configfile);	# &getConfig; would work too

	return $retcode;
}

