#!/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
# Theme Stuff based upon ReplaySchedule.pl by Kevin J. Moye
#  $Id: rg_scheduler.pl,v 1.9 2003/07/24 02:00:22 pvanbaren Exp $
#
# SCHEDULE RESOLVER MODULE: RG_SCHEDULER 
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
#  scheduler_do_batch_update
#    - If some type of nightly processing is perferred or required this should
#      return true (1), otherwise return 0.
#
#  schedulebar_supported
#    - If the module supports the ScheduleBar (within replayguide.pl) this should
#      return true (1), otherwise return 0.
#
#  todo_supported
#    - If the module supports the ToDo List (within replayguide.pl) this should
#      return true (1), otherwise return 0.
#    
#-----------------------------------------------------------------------------------

use POSIX qw( getcwd );
use Time::Local;

my $_version = "Personal ReplayGuide|replaySchedule Schedule Resolver Module|1|1|108|Philip Van Baren,Kevin J. Moye";


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

#------------------------------------------------
sub getFreshScheduleTable {
	#
	# Refresh the tables used to determine scheduled programs
	#---------------------------------------------------------------------------

	my $retval;
	my $replayid = shift;
	my $replayaddress = $rtvaddress{ $replayid };
	my $replaylabel = $rtvlabel{ $replayid };
	my $s2sdebug = $debug;
	my $prefix = "";
	my $curr_dir = getcwd;

	if ($replayid eq $null) {
		writeDebug("replayid is null!");
		return 1;
	}

	if ($schedule2sql eq $null) {
		writeDebug("schedule2sql is undefined, check prg.conf settings!");
		return 1;
	}

	if ($replayaddress eq $null) {
		writeDebug("no address found for Replay #$replayid");
		return 1;
	}

	my $old_verbose = $verbose;

	$verbose = 1;

	if ($schedule2sql =~ /\.pl/) {
		$prefix = $^X;
		if ($prefix =~ /\.dll/i) {
			$prefix = "";
		}
	}

	writeLogFile("Calling: '$prefix $schedule2sql $replayaddress PRG $s2sdebug' from '$curr_dir'");

	my $result = system("$prefix $schedule2sql $replayaddress PRG $s2sdebug");

	if ($result == -1) {
		writeDebug("Could not execute $schedule2sql.  Check file permissions.");
		$retval = 1;
	}else{
		# Get the exit value from schedule2sql.pl
		$retval = $? >> 8;
	}

	$verbose = $old_verbose;

	return $retval;
}

#------------------------------------------------
sub getCachedScheduleTable {
	# Initialize the variables used for finding scheduled programs
	#---------------------------------------------------------------------------

	my $retcode = 0;
	my $replayid = shift;

	# Everything is in the database already, so there is nothing
	# to initialize here

	return $retcode;
}

#------------------------------------------------
sub ProcessScheduleTable {
	# Do any processing requires to prepare the schedule tables for use
	#---------------------------------------------------------------------------

	return 1;
}

#---------------------------------------------------------------------------------------
sub compareScheduleTable {
        # Compare the scheduled events with the displayed events
        # This assumes $Stmt is defined such that it returns the displayed events
        #---------------------------------------------------------------------------

	# Nothing needed as the info is already in the database

	my $Stmt = shift;
	return 1;
}

#---------------------------------------------------------------------------------------
sub getScheduleDetails {
	#
	# Build a RTV Status Icon
	#
	# Parameter: none
	#
	# ------------------------------------------------------------------------------

	my $inp_programid = shift;
	my $inp_timing = shift;

	my $retval = "";
	my $program_icon = "";
	my $program_text = "";
	my $program_icon_alt = "";

	my $program_replayid = 0;
	my $program_conflict = 0;
	my $program_guaranteed = 0;
	my $program_recurring = 0;
	my $program_theme = 0;
	my $program_beforepad = 0;
	my $program_afterpad = 0;

	my $specialdebug = 0;

	if ( ! $rtvaccess) {
		if ($specialdebug) {
			writeDebug("getScheduleDetails::rtvaccess disabled");
		}
	} else {
		if ($specialdebug) {
			writeDebug("getScheduleDetails::rtvaccess enabled, getting schedule icons");
		}
		
		#-------------------------------------------------
		# Read the scheduling information from the database
		#-------------------------------------------------

		my $Stmt = "SELECT * FROM $db_table_schedule WHERE programid = '$inp_programid';";

		my $db_handle = &StartDSN;

		if ($specialdebug) {
			writeDebug("getScheduleDetails::database handle is $db_handle");
			writeDebug("getScheduleDetails::attempting to execute query $Stmt");
		}


		my $handle = sqlStmt($db_handle,$Stmt);
		

		if ( $handle ) {

			#-------------------------------------------------
			# Iterate through all replaytv's scheduled for this program
			#-------------------------------------------------

			my $color = "";
			while ( $row = $handle->fetchrow_hashref ) {
				$program_replayid = $row->{'replayid'};
				$program_beforepad = $row->{'padbefore'};
				$program_afterpad = $row->{'padafter'};
				$program_conflict = $row->{'conflict'};
				$program_guaranteed = $row->{'guaranteed'};
				$program_recurring = $row->{'recurring'};
				$program_theme = $row->{'theme'};

				#-------------------------------------------------
				# Note: should map to bits, and do a table lookup
				# so the code is cleaner and faster
				#-------------------------------------------------

				if ($specialdebug) {
					writeDebug("getScheduleDetails::program $row->{'programid'} RTV: $program_replayid C: $program_conflict G: $program_guaranteed R: $program_recurring T: $program_theme -: $program_beforepad +: $program_afterpad");
				}


				if ($program_theme) {
					if ($showrtvthemes) {
						if ($program_guaranteed) {
							$program_text = "Guaranteed Theme";
							if ($program_conflict) { 
								$program_icon = $image_cgt; 
							}else{ 
								$program_icon = $image_gt; 
							}
				    		} else {
							$program_text = "Theme";
							if ($program_conflict) { 
								$program_icon = $image_tl; 
							}else{ 
								$program_icon = $image_tw; 
							}
		    				}
					}

					#-------------------------------------------------
					# Theme match background color always shown
					# To hide this, just set colors to an empty string
					#-------------------------------------------------

					if( $program_conflict ) {
						$program_text .= " in Conflict"; 
						$color = combine_color($color,$color_theme_conflict[ $inp_timing ]);
					} else {
						$color = combine_color($color,$color_theme[ $inp_timing ]);
					}
				} elsif ($program_recurring) {
					if($program_guaranteed) {
						#-------------------------------------------------
						# Guaranteed Recurring	
						#-------------------------------------------------
						if (($program_afterpad > 0) && ($program_beforepad > 0))  {
							$program_text = "Guaranteed, Recurring, Padded";
							if ($program_conflict) { 
								$program_icon = $image_cppgr; 
							}else{ 
								$program_icon = $image_ppgr; 
							}
						} elsif ($program_afterpad > 0)  {
							$program_text = "Guaranteed, Recurring, Post-Padded";
							if ($program_conflict) { 
								$program_icon = $image_capgr; 
							}else{ 
								$program_icon = $image_apgr; 
							}
						} elsif ($program_beforepad > 0)  {
							$program_text = "Guaranteed, Recurring, Pre-Padded";
							if ($program_conflict) { 
								$program_icon = $image_cbpgr; 
							}else{ 
								$program_icon = $image_bpgr; 
							}
						} else {
							$program_text = "Guaranteed, Recurring";
							if ($program_conflict) { 
								$program_icon = $image_cgr; 
							}else{ 
								$program_icon = $image_gr; 
							}
						}
					}else{
						#-------------------------------------------------
						# Non-guaranteed Recurring
						#-------------------------------------------------
						if (($program_afterpad) && ($program_beforepad))  {
							$program_text = "Recurring, Padded";
							if ($program_conflict) { 
								$program_icon = $image_cppr; 
							}else{ 
								$program_icon = $image_ppr; 
							}
						} elsif ($program_afterpad)  {
							$program_text = "Recurring, Post-Padded";
							if ($program_conflict) { 
								$program_icon = $image_capr; 
							}else{ 
								$program_icon = $image_apr; 
							}
						} elsif ($program_beforepad)  {
							$program_text = "Recurring, Pre-Padded";
							if ($program_conflict) { 
								$program_icon = $image_cbpr; 
							}else{ 
								$program_icon = $image_bpr; 
							}
						} else {
							$program_text = "Recurring";
							if ($program_conflict) { 
								$program_icon = $image_cr; 
							}else{ 
								$program_icon = $image_r; 
							}
						}
					}
					if ($program_conflict) {
						$program_text .= " in Conflict"; 
						$color = combine_color($color,$color_conflict[ $inp_timing ]);
					} else {
						$color = combine_color($color,$color_scheduled[ $inp_timing ]);
					}
				}else{
					if ($program_guaranteed) {
						if (($program_afterpad) && ($program_beforepad))  {
							$program_text = "Guaranteed, Single, Padded";
							if ($program_conflict) { 
								$program_icon = $image_cppgs; 
							}else{ 
								$program_icon = $image_ppgs; 
							}
						} elsif ($program_afterpad)  {
							$program_text = "Guaranteed, Single, Post-Padded";
							if ($program_conflict) { 
								$program_icon = $image_capgs;
							}else{ 
								$program_icon = $image_apgs; 
							}
						} elsif ($program_beforepad)  {
							$program_text = "Guaranteed, Single, Pre-Padded";
							if ($program_conflict) { 
								$program_icon = $image_cbpgs; 
							}else{ 
								$program_icon = $image_bpgs; 
							}
						} else {
							$program_text = "Guaranteed, Single";
							if ($program_conflict) { 
								$program_icon = $image_cgs; 
							}else{ 
								$program_icon = $image_gs; 
							}
						}
					}else{
						if (($program_afterpad) && ($program_beforepad))  {
							$program_text = "Single, Padded";
							if ($program_conflict) { 
								$program_icon = $image_cpps; 
							}else{ 
								$program_icon = $image_pps; 
							}
						} elsif ($program_afterpad)  {
							$program_text = "Single, Post-Padded";
							if ($program_conflict) { 
								$program_icon = $image_caps; 
							}else{ 
								$program_icon = $image_aps; 
							}
						} elsif ($program_beforepad)  {
							$program_text = "Single, Pre-Padded";
							if ($program_conflict) { 
								$program_icon = $image_cbps; 
							}else{ 
								$program_icon = $image_bps; 
							}
						}else{
							$program_text = "Single";
							if ($program_conflict) { 
								$program_icon = $image_cs; 
							}else{ 
								$program_icon = $image_s; 
							}
						}
					}
					if ($program_conflict) {
						$program_text .= " in Conflict"; 
						$color = combine_color($color,$color_conflict[ $inp_timing ]);
					}else{
						$color = combine_color($color,$color_scheduled[ $inp_timing ]);
					}
				}

				$program_icon_alt = $rtvlabel{$program_replayid} . " - " . $program_text;
	
				if ($showrtvicons) {
					if (length($program_icon) > 0) {
						if (substr($program_icon,0,7) eq "http://" ) {
							$retval .= "<img src=$program_icon ALT=\"$program_icon_alt\">";
						}else{
							$retval .= "<img src=$imagedir/$program_icon ALT=\"$program_icon_alt\">";
						}
						if ($showrtvtext) {
							$retval .= "($program_icon_alt)";
						}
					}else{
						if ($specialdebug) {
							writeDebug("getScheduleDetails::scheduled program ($row->{'programid'}) is a theme but theme display is disabled");
						}
					}
				}else{
					if ($showrtvtext) {
						$retval .= "$program_icon_alt";
					}
				}
			}
			#-------------------------------------------------
			# Set the global bgcolor with the desired color
			#-------------------------------------------------

			if($color) {
				$bgcolor = $color;
			}
		}

		endDSN($handle,$db_handle);
	}

	return $retval;
}

#------------------------------------------------
sub combine_color {
	my $retval;
	my $a = shift;
	my $b = shift;
	if( (length($a) != 7) || (length($b) != 7) ) {
		if( $b ) {
			$retval = $b;
		} else {
			$retval = $a;
		}
	} else {
		# Merge the two colors together using averaging
		$ar = hex substr($a,1,2);
		$ag = hex substr($a,3,2);
		$ab = hex substr($a,5,2);
		$br = hex substr($b,1,2);
		$bg = hex substr($b,3,2);
		$bb = hex substr($b,5,2);
		$retval = sprintf('#%02x%02x%02x', ($ar+$br)>>1, ($ag+$bg)>>1, ($ab+$bb)>>1);
	}
	return $retval;
}

#------------------------------------------------
sub AboutScheduler{
	# About Schedule Module
	#---------------------------------------------------------------------------

	my $about = "";
	$about .= "rg_scheduler SRM for replaySchedule by Kevin J. Moye and Philip Van Baren.";

	return $about;
}

#------------------------------------------------
sub SchedulerDefaultRefresh{
	# Refresh options for the scheduler module.
	#
	# Time in minutes between guide refreshes 
	# (0 is batch only if do_batch_update is enabled, otherwise completely
        # disabled.)
	#---------------------------------------------------------------------------
		
	return 0;
}


#------------------------------------------------
sub SchedulerDoBatchUpdate{
	# Refresh options for the scheduler module.
	#
	# Should scheduler module be updated at SQL time?
	#---------------------------------------------------------------------------
		
	return 1;
}


#------------------------------------------------
sub SchedulebarSupported{
	# Does this processor support the schedulebar?
	#---------------------------------------------------------------------------

	return 1;
}

#------------------------------------------------
sub ToDoSupported{
	# Does this processor support the todolist?
	#---------------------------------------------------------------------------

	return 1;
}

1;
