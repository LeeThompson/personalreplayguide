#!/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
# Theme Stuff based upon ReplaySchedule.pl by Kevin J. Moye
#  $Id: rg_scheduler.pl,v 1.9 2003/07/24 02:00:22 pvanbaren Exp $
#
# BATCH REFRESH FUNCTIONS
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
# This module will refresh guide data using the scheduler module's 
# GetFreshScheduleTable call.    
#
# To save time, only scheduler modules that return true (1) for the 
# scheduler_do_batch_update call will be processed.
#
# DEVS: If your scheduler module uses the schedule table within SQL (or similar)
# we highly encourage you to use the scheduler_do_batch_update functionality.
#
#-----------------------------------------------------------------------------------

use POSIX qw( strftime getcwd );
use Time::Local;

my $_version = "Personal ReplayGuide|Batch Guide Refresh Library|1|0|5|Lee Thompson,Philip Van Baren,Kanji T. Bates,Kevin J. Moye";

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

#-----------------------------------------------------------------------------------
sub refreshRTV { 
	#
	# Refresh ReplayTV scheduling for all units.
	#
	# Optional Parameter is if this is silent or not (default is silent)
	# Verbosity of 2 is debug.
	#
	#-------------------------------------------------------------------
	my $local_verbose = shift;	

	if ($local_verbose eq $null) {
		$local_verbose = int $verbose;		# Try to use global if it's there
	}

	if ($local_verbose > 1) {
		writeDebug("refreshRTV::Start");
	}
	
	if ($local_verbose) {
		writeDebug("Refreshing ReplayTV Schedule Data");
	}

	#-------------------------------------------------------------------
	# Load Scheduler Plug-In 
	#-------------------------------------------------------------------

	if ($local_verbose > 1) {
		writeDebug("Loading Plug-In $scheduler");
	}

	require $scheduler;			# Functions handling scheduled recording display
	identifyLoadedModules($scheduler);
	writeDebug(&AboutScheduler);

	if (!&SchedulerDoBatchUpdate) {
		if ($local_verbose > 1) {
			writeDebug("Schedule Resolver Module ($scheduler) does not support batch updates");
		}
		return 0;
	}

	my $replaylist = "";
	my $db_handle = &StartDSN;
	my $Stmt = "SELECT * FROM $db_table_replayunits ORDER BY replayaddress;";
	my $lastsnapshot = 0;
	my $right_now = time;
	my $addr;
	my $rows = 0;

	if ($local_verbose > 1) {
		writeDebug("SQL: $db_handle -> $Stmt");
	}

	my $sth = sqlStmt($db_handle,$Stmt);

	if( $sth ) {
		while ( $row = $sth->fetchrow_hashref ) {
			$rows++;
			

			my $replayid = $row->{'replayid'};

			$replaylist = buildcommastring($replaylist,$replayid);

			$replaylist .= "$replayid";
			$rtvlabel{$replayid} = $row->{'replayname'};
			$rtvaddress{$replayid} = $row->{'replayaddress'};
			$rtvport{$replayid} = $row->{'replayport'};
			$rtvversion{$replayid} = $row->{'replayosversion'};
			$guideversion{$replayid} = $row->{'guideversion'};
			$categories{$replayid} = $row->{'categories'};
			$lastsnapshot = $row->{'lastsnapshot'};

			if ($local_verbose) {
				writeDebug("Refreshing Data for $rtvlabel{$replayid}");
			}

			if (0 != getFreshScheduleTable($replayid)) {

				if ($local_verbose) {
					writeDebug("getFreshScheduleTable Failed for $rtvlabel{$replayid}");
				}
			}else{
				if ($local_verbose) {
					writeDebug("getFreshScheduleTable Complete for $rtvlabel{$replayid}");
				}
				
				my $Update = "UPDATE $db_table_replayunits SET lastsnapshot = $right_now WHERE replayid = '$replayid';";
				my $db_handle = &StartDSN;

				if ($local_verbose) {
					writeDebug("Updating Database for $rtvlabel{$replayid}...");
				}
			
				if ( ! sqlStmt($db_handle,$Update) ) {
					if ($local_verbose) {
						writeDebug("Database update failed for $rtvlabel{$replayid}");
					}
				}else{
					if ($local_verbose) {
						writeDebug("Datebase update completed for $rtvlabel{$replayid}");
					}
				}

				if ($local_verbose > 1) {
					writeDebug("Closing Database Handle $db_handle");
				}

				endDSN("",$db_handle);
				undef $db_handle;
			}


		}
	}

	if ($local_verbose > 1) {
		writeDebug("Closing Database Handle $db_handle");
	}

	endDSN($sth,$db_handle);
	undef $db_handle;

	if ($rows) {
		if ($local_verbose) {
			writeDebug("Refresh Complete");
		}
	}else{
		if ($local_verbose) {
			writeDebug("No ReplayTVs Defined.");
		}
	}
		

	if ($local_verbose > 1) {
		writeDebug("refreshRTV::Exiting");
	}

	return 1;
}


