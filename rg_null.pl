#!/usr/bin/perl
#
#
# PERSONAL REPLAYGUIDE SCHEDULER MODULE
# NULL MODULE (for no RTV support)
#
#------------------------------------------------------------------------------------
# This file is part of Personal ReplayGuide (C) 2004 by Lee Thompson
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

my $_version = "Personal ReplayGuide|Null Schedule Resolver Module|1|0|4|Lee Thompson";

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

sub getFreshScheduleTable {
	return 1;
}

sub getCachedScheduleTable {
	return 1;
}

sub ProcessScheduleTable {
	return 1;
}

sub compareScheduleTable {
	return 1;
}

sub getScheduleDetails {
	return "";
}

sub AboutScheduler {
	return "(Null SRM) ReplayTV Support Disabled";
}

sub SchedulerDefaultRefresh{
	return 0;
}

sub SchedulerDoBatchUpdate {
	return 0;
}

sub SchedulebarSupported {
	return 0;
}

sub ToDoSupported {
	return 0;
}

1;

