#!/usr/bin/perl
#
# Personal ReplayGuide SQL Converter
# by Phil Van Baren
# based on code by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
#  $Id: schedule2sql.pl,v 1.18 2003/11/04 00:28:36 pvanbaren Exp $
#
# RG_SCHEDULER SQL INJECTOR
#
# Requirements: 
#	replaySchedule
#
# replaySchedule is (C) 2003 by Kevin J. Moye
# http://replayguide.sourceforge.net/replaySchedule
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

use POSIX qw( strftime getcwd );
use English;
use Time::Local;
require LWP::Simple;
require LWP::UserAgent;
require HTTP::Request;
require HTTP::Headers;

my $_version = "Personal ReplayGuide|replaySchedule SRM to SQL Converter|1|0|21|Philip Van Baren,Kanji T. Bates,Lee Thompson";

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
require 'rg_info.pl';			# Load database info
require 'rg_config.pl';			# Load config library

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
# Debug Options
#-----------------------------------------------------------------------------------
$do_not_drop_rows = 0;			# Do not DELETE rows first
$do_not_insert = 0;			# Skip the DB insert

#-----------------------------------------------------------------------------------
# Define Options
#-----------------------------------------------------------------------------------
$debug = 1;				# Debug Messages
$multiplier = 1000;			# Default Multiplier
$maxrows = 0;				# Maximum Number of rows to INSERT
$datafeed = "xmltv";			# Default Format (xmltv or datadirect)
$cnf_xmlfile = "na.xml";		# XMLTV output
$verbose = 1;				# Talky

#-----------------------------------------------------------------------------------
# Set Constants
#-----------------------------------------------------------------------------------

$min_rs = 116.26;			# Minimum version of replaySchedule 
					# NOTE: It is not a fatal error if the rs
					#       executable is less than this value.
					#-------------------------------------------

(my $parent,my $desc,my $major,my $minor,my $build,my $authors) = parseModuleData($prg_module{$module_name});

$program_title = $parent;
$program_module = $desc;
$program_author = buildMultiWordList($authors);
$program_version = "$major.$minor";
$program_build = $build;

$rows = 0;
$null = "";

#-----------------------------
# OS-Sensitive defaults
#-----------------------------

if ($^O eq 'MSWin32') {
	$replaySchedule = "replaySchedule.exe";	# Command to run replaySchedule
} else {
	$replaySchedule = "./replaySchedule";	# Command to run replaySchedule
}



$configfile = "schd2sql.conf";			# This is optional
$configstatus = getConfig($configfile);		# Read Configuration

#-------------------------------------------------------------------------------
# Process Command Line 
#-------------------------------------------------------------------------------
# Syntax: schedule2sql.pl IPADDRESS FLAG VERBOSE
#
# FLAG is "PRG" which allows it to make an exception and be run in HTTP context.
#
# VERBOSE is optional and can be 1 (true) or 0 (false).   If true then output
# will be rendered to STDOUT in either HTML or plaintext (depending on context).
#
#-------------------------------------------------------------------------------

$rtvaddress = $ARGV[0];
$specialflag = $ARGV[1];
if (defined($ARGV[2])) { 
	$verbose = int $ARGV[2];
}

#----------------------------------------------------------------------------------
# Check to see if this is being run from the console
#----------------------------------------------------------------------------------

$RemoteAddress = $ENV{'REMOTE_ADDR'};

if ($RemoteAddress eq $null) {
	$RemoteAddress = "127.0.0.1";
	$remotemode = 0;
}else{
	if (uc $specialflag eq 'PRG') {
		$remotemode = 0;		# Special Permission Granted
	}else{
		$remotemode = 1;
	}
}


#-----------------------------------------------------------------------------------
# Display Header
#-----------------------------------------------------------------------------------

writeDebug("********************************************************");
writeDebug("$program_title\:$program_module v$program_version (Build $program_build)");
writeDebug("Running as $script_pathname with PID $$");
writeDebug("Remote Address: $RemoteAddress");
if ($verbose) {
	writeDebug("Console Output: Enabled");
}else{
	writeDebug("Console Output: Disabled");
}


identifyLoadedModules();

#-------------------------------------------------------------------
# Check to see if the IP Address in $RemoteAddress has access to RTV
#-------------------------------------------------------------------

if (hasAccess($RemoteAddress)) {
	$remoteaccess = 0;		
}else{	
	$remoteaccess = 0;
}

if (($remotemode) && (!$remoteaccess)) {
	&InitializeDisplay;
	abend("$program_module runs in console mode only");
}else{
	if ($remotemode) {
		&InitializeDisplay;
	}
}


#-------------------------------------------------------------------
# Check command line arguments
#-------------------------------------------------------------------

writeDebug("Command Line: IP: $ARGV[0] FLAG: $ARGV[1] VERBOSE: $ARGV[2]");

if( ! $rtvaddress ) {
	abend("rtvaddress not defined!"); 
}



#-----------------------------------------------------------------------------------
# Override default listing selection if listingmap is defined
#-----------------------------------------------------------------------------------

if( $listingmap{$rtvaddress} ) {
   $cnf_xmlfile = $listingmap{$rtvaddress};
}

$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );
$started = time;

if ($debug) {
	writeDebug("Debug Messages are ON");
}

writeDebug("Current Time: $now");
writeDebug("Connecting to ReplayTV: $rtvaddress");

#-------------------------------------------------------------------
# Set up Database
#-------------------------------------------------------------------

&InitDB;
&InitDSN;

#-------------------------------------------------------------------
# Start Database
#-------------------------------------------------------------------

$prgdb_handle = &StartDSN;

if ($prgdb_handle ne $null) {
	writeDebug("Database Connection Established! $DATASOURCE{DSN} ($prgdb_handle)");
}else{
	writeDebug("Attempt to Connect Failed: " . &GetLastSQLError()); 
	abend("Could not establish database connection!");
}

#-------------------------------------------------------------------
# Get the unique replayid for this address
#-------------------------------------------------------------------

$Stmt = "SELECT * FROM $db_table_replayunits WHERE replayaddress = '$rtvaddress';";
$handle = sqlStmt($prgdb_handle,$Stmt);

if( $handle ) {
	if ( $row = $handle->fetchrow_hashref ) {
		$replayid = $row->{'replayid'};
		$replayname = $row->{'replayname'};
		$replayport = $row->{'replayport'};
	} else {
		abend("No replaytv unit configured for address $rtvaddress");
	}
	$handle->finish;
} else {
	my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
	abend("Failed: $sql_error");
}


#-------------------------------------------------------------------
# Clean previous schedule info
#-------------------------------------------------------------------

if ($do_not_drop_rows) {
	writeDebug("Skipping Row Delete");
}else{
	writeDebug("Deleting previous schedule info ...");

	$Stmt = "DELETE FROM $db_table_schedule WHERE replayid = '$replayid';";

	if ( sqlStmt($prgdb_handle,$Stmt) ) {
		writeDebug("Database flushed");	
	}else{
		my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
		abend("Failed: $sql_error");
	}
}

$FieldNames = "programid, replayid, firstrun, guaranteed, theme, " .
	"recurring, manual, conflict, created, padbefore, padafter";

#-------------------------------------------------------------------
# If INSERT is disabled, log data to a CSV
#-------------------------------------------------------------------

if ($do_not_insert) {
	open(CSVFILE, ">schedule.csv");
	writeDebug("SQL Insert Disabled, Writing to CSV (schedule.csv)");

	print CSVFILE $FieldNames;
	print CSVFILE "\n";
}


$categories = "";
$replayversion = 0;
$guideversion = 0;


#-----------------------------------------------------------------------------------
# Get version information for replaySchedule
#-----------------------------------------------------------------------------------

if(!open(REPLAYSCHEDULE, "$replaySchedule --quiet |")) {
        abend("Could not execute $replaySchedule");
}

while(<REPLAYSCHEDULE>) {
		$line = $_;
		chomp($line);
		$original_line = $line;

		if ( /Version: / ) {
			$string = $line;
		}
}

close REPLAYSCHEDULE;

(my $junk,my $junk,my $rs_title,my $rs_version,my $rs_date,my $rs_time,my $rs_author,my $junk,my $junk) = split( / /,$string,9);

writeDebug("$replaySchedule version $rs_version by $rs_author ($rs_date $rs_time)");

if ($rs_version < $min_rs) {
	writeDebug("Warning! Your copy of $replaySchedule is older than the version tested with this version of $program_title ($min_rs)");
}

#-----------------------------------------------------------------------------------
# Dump the scheduled recordings to an XML file
#-----------------------------------------------------------------------------------

if(($replayport) && ($replayport != 80)) {
	$addr = "$rtvaddress:$replayport";
} else {
	$addr = $rtvaddress;
}

$cmd_string = "";

if($cnf_xmlfile =~ m/xml/) {
	$cmd_string = "--xml - --ip $addr --schedule $cnf_xmlfile --quiet";
} else {
	$cmd_string = "--xml - --ip $addr --guide $cnf_xmlfile --quiet ";
}

#-----------------------------------------------------------------------------------
# If format is datadirect, tell replaySchedule
#-----------------------------------------------------------------------------------

if((uc $datafeed eq 'DATADIRECT') || (uc $datafeed eq 'DD')){
	$cmd_string = "--dd " . $cmd_string;
}

writeDebug("Calling->$replaySchedule $cmd_string");

if(!open(REPLAYSCHEDULE, "$replaySchedule $cmd_string |")) {
        abend("Failed to download schedule from $rtvaddress");
}

#-------------------------------------------------------------------
# Convert XML to SQL
#-------------------------------------------------------------------

writeDebug("Parsing Data and Inserting Rows");

while(<REPLAYSCHEDULE>) {

		#-----------------------------------------------------------
		# Parse XML
		#-----------------------------------------------------------

		$line = $_;
		chomp($line);
		$original_line = $line;

		#-----------------------------------------------------------
		# VERSION INFO
		#-----------------------------------------------------------

		if ( /<replayversion/ ) {
			$string = $line;
			$string =~ s/.*<replayversion>([^\"]*)<.*/$1/;
			$replayversion = int $string;
		}

		if ( /<guideversion/ ) {
			$string = $line;
			$string =~ s/.*<guideversion>([^\"]*)<.*/$1/;
			$guideversion = int $string;
		}

		#-----------------------------------------------------------
		# CATEGORIES
		#-----------------------------------------------------------

		if ( /<category id=/ ) {
			$string = $line;
			$string =~ s/.*<category id=\"([^\"]*)\">([^<]*)<.*/$1,$2/;
			if($categories eq "") { $categories = $string; }
			else { $categories .= ";" . $string; }
		}

		#-----------------------------------------------------------
		# PROGRAMS
		#-----------------------------------------------------------

		if ( /<programme/ ) {
			$program_start = $line;
			$program_start =~ s/.*start="(\d*)[^"]*.*/$1/;
			$program_tmsid = 0;
			$program_channel = "";
			$program_tuning = 0;
			if($line =~ m/tmsid="([^"]+)/ ) {
				$program_tmsid = $1;
			}
			if ($line =~ m/channel="([^"]*)/ ) {
				($program_tuning,$program_channel) = split(/ /,$1);
				$program_tuning = int $program_tuning;
			}

			$program_title = "";
			$program_subtitle = "";
			$rtvaddress = "";
			$firstrun = 0;
			$guaranteed = 0;
			$theme = 0;
			$recurring = 0;
			$manual = 0;
			$conflict = 0;
			$created = "";
			$padbefore = 0;
			$padafter = 0;
		}

		if ( /<title>/ ) {
			$program_title = $line;
			$program_title =~ s/.*<title>([^<]*)\W.*/$1/;
		}

		if ( /<sub-title>/ ) {
			$program_subtitle = $line;
			$program_subtitle =~ s/.*<sub-title>([^<]*)\W.*/$1/;
		}

		if ( /<created>/ ) {
			$created = $line;
			$created =~ s/.*<created>([^<]*)\W.*/$1/;
		}

		if ( /<address>/ ) {
			$rtvaddress = $line;
			$rtvaddress =~ s/.*<address>([^<]*)\W.*/$1/;
		}

		if ( /<pad-before/ ) {
			$padbefore = $line;
			$padbefore =~ s/.*<pad-before>([^<]*)\W.*/$1/;
			$padbefore = int $padbefore;
		}
	
		if ( /<pad-after/ ) {
			$padafter = $line;
			$padafter =~ s/.*<pad-after>([^<]*)\W.*/$1/;
			$padafter = int $padafter;
		}

		if ( /<guaranteed>1/ ) {
			$guaranteed = 1;
		}

		if ( /<firstrun>1/ ) {
			$firstrun = 1;
		}

		if ( /<type.*recurring/i ) {
			$recurring = 1;
		}

		if ( /<type.*theme/i ) {
			$theme = 1;
		}

		if ( /<manual>1/ ) {
			$manual = 1;
		}

		if ( /<conflict/ ) {
			if( /Loser/ ) {
				$conflict = 1;  # Will NOT record
			} else {
				$conflict = 0; 	# Will record
			}
		}

	        if ( /<\/programme/ ) {

			$Stmt = "";
		
			$dataok = 1;


			($Y,$M,$D,$h,$m,$s) = unpack 'A4 A2 A2 A2 A2 A2', $program_start;
			$program_start = "$Y-$M-$D $h:$m:$s";
			$Y = int $Y;
		
			if ($Y < 1) {
				$dataok = 0;
			}
		
			$created = as_epoch_seconds($created);

			$program_title = filterfield($program_title);
			$program_subtitle = filterfield($program_subtitle);	
		
			if ($dataok) {
				if ($do_not_insert) {
					$FieldValues = "'$program_title', '$replayid', $firstrun, $guaranteed, " . 
						"$theme, $recurring, $manual, $conflict, '$created', " .
						"$padbefore, $padafter";
					print CSVFILE $FieldValues;
					print CSVFILE "\n";

					$rows++;

				}else{
					if (&PostSQL) {
						$rows++;
					}
				}
			}

			#print ".";

			if ($maxrows) {
				if ($rows > $maxrows) {
					close REPLAYSCHEDULE;
					if ($do_not_insert) {
						close CSVFILE;
					}
					abend("Max Rows Reached ($maxrows)");
				}
			}

		}

}

close REPLAYSCHEDULE;

#-----------------------------------------------------------------------------------
# Get the return value from replaySchedule
#-----------------------------------------------------------------------------------

$retcode = $? >> 8;


writeDebug("Completed processing replaySchedule data.   $replaySchedule returned $retcode.");


if ($do_not_insert) {
	close CSVFILE;
	abend("Done! do_not_insert set to $do_not_insert.");
}elsif(! $categories || ! $rows) {
	writeDebug("** No scheduled shows ** ");
}else{
	#---------------------------------------------------------------------------
	# Set the category list for this replay unit
	#---------------------------------------------------------------------------

	$replayosversion = $guideversion*10 + 30 + $replayversion;
	$Stmt = "UPDATE $db_table_replayunits SET categories='$categories', " .
		"replayosversion='$replayosversion', " .
		"guideversion='$guideversion'" .
		"WHERE replayid = '$replayid';";

	if ( sqlStmt($prgdb_handle,$Stmt) ) {
		writeDebug("Category list was updated");
	}else{
		my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
		abend("Category list update failed: $sql_error");

	}
}

writeDebug("$rows rows were added");


$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Terminating Database Connection from $DATASOURCE{DSN} ($prgdb_handle)");
endDSN($handle,$prgdb_handle);

writeDebug("Job finished at $now ($runtime seconds)");

writeDebug("exiting module with retcode $retcode");

&ShowHTTPFooter;

writeDebug("********************************************************");

exit($retcode);




#----------------------------------------------------------------------------
sub PostSQL{
	#
	# Insert a Row into SCHEDULE table 
	#
	# ------------------------------------------------------------------------------

	my $iRetCode = 0;
	my $programid = "";

	#--------------------------------------------	
	# Locate the program id for this show
	#--------------------------------------------	

	if( $program_tmsid ) {
		# Try find the channel using the tmsid
		$Stmt = "SELECT * FROM $db_table_tvlistings " .
			"WHERE tmsid = '$program_tmsid' AND starttime = '$program_start';";
		$handle = sqlStmt($prgdb_handle,$Stmt);
		if ( $handle ) {
			if( $row = $handle->fetchrow_hashref ) {
				$programid = $row->{'programid'};
			}
		}
	}	

	if( !$programid ) {
		# Try with the channel name
		$Stmt = "SELECT * FROM $db_table_tvlistings " .
			"WHERE channel = '$program_channel' AND starttime = '$program_start';";
		$handle = sqlStmt($prgdb_handle,$Stmt);
		if ( $handle ) {
			if( $row = $handle->fetchrow_hashref ) {
				$programid = $row->{'programid'};
			}
		}
	}

	if( ! $programid ) {
		if ( $debug ) {
			writeDebug("** Show not found in tvlistings database: $program_title on $program_channel at $program_start");
		}
		$iRetCode = 0;
	}else{
		$FieldValues = "'$programid', '$replayid', $firstrun, $guaranteed, " . 
			"$theme, $recurring, $manual, $conflict, '$created', " .
			"$padbefore, $padafter";
		$Stmt = "INSERT INTO $db_table_schedule ($FieldNames) VALUES ($FieldValues);";
		if ( sqlStmt($prgdb_handle,$Stmt) ) {
			$iRetCode = 1;
	    	}else{
			my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
			abend("Insert Failed: $sql_error");
		}
	}

	return $iRetCode;
}

