#!/usr/bin/perl
#
# Personal ReplayGuide Configuration Utility
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
#  $Id: configure.pl,v 1.6 2003/07/19 13:33:44 pvanbaren Exp $
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

my $_version = "Personal ReplayGuide|ReplayTV Configure|1|0|17|Lee Thompson,Philip Van Baren,Kanji T. Bates";

#------------------------------------------------------------------------------------
# Determine Current Directory 
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

require 'rg_config.pl';			# Load config functions
require 'rg_common.pl';			# Load common functions
require 'rg_database.pl';		# Load database functions
require 'rg_info.pl';			# Load database config

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
$do_not_drop_rows = 0;			# Controls of replayunits gets replaced
$do_not_insert = 0;			# Skip the DB insert

#-----------------------------------------------------------------------------------
# Define Options
#-----------------------------------------------------------------------------------
$debug = 0;				# Debug Messages


$configfile = "configure.conf";			# This is optional
$configstatus = getConfig($configfile);		# Read Configuration
$verbose = 1;

#-----------------------------------------------------------------------------------
# Set Constants
#-----------------------------------------------------------------------------------

$null = "";

(my $parent,my $desc,my $major,my $minor,my $build,my $authors) = parseModuleData($prg_module{$module_name});

$program_title = $parent;
$program_module = $desc;
$program_author = buildMultiWordList($authors);
$program_version = "$major.$minor";
$program_build = $build;

$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );
$started = time;

#----------------------------------------------------------------------------------
# Check to see if this is being run from the console
#----------------------------------------------------------------------------------

$RemoteAddress = $ENV{'REMOTE_ADDR'};

if ($RemoteAddress eq $null) {
	$RemoteAddress = "127.0.0.1";
	$remotemode = 0;
}else{
	$remotemode = 1;
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

if ($debug) {
	&writeOutput("Debug Messages are ON");
}


#-------------------------------------------------------------------
# Check to see if the IP Address in $RemoteAddress has access to RTV
#-------------------------------------------------------------------

if (hasAccess($RemoteAddress)) {
	$remoteaccess = 0;				# Disabled	
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


$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );
$started = time;

writeDebug("Job started at $now");

#-------------------------------------------------------------------
# Set up Database
#-------------------------------------------------------------------

&InitDB;
&InitDSN;

#-------------------------------------------------------------------
# Start Database
#-------------------------------------------------------------------

$DSNLink = &StartDSN;

if ($DSNLink ne $null) {
	writeDebug("Database Connection Established to $DATASOURCE{DSN} using handle $DSNLink");
}else{
	writeDebug("Attempt to Connect to $DATASOURCE{DSN} Failed: " . &GetLastSQLError()); 
	abend("Could not establish database connection!");
}



#----------------------------------------------------------------
# Set Defaults
#----------------------------------------------------------------

$inp_scriptdir = "";

#----------------------------------------------------------------
# Start
#----------------------------------------------------------------

writeDebug("Entering Interactive Mode");

print "\nWelcome to the $program_title configuration utility.\n";


#----------------------------------------------------------------
# Gather Information
#----------------------------------------------------------------

$inp_dortv = 1;

if ($inp_dortv) {
	$choiceok = 0;
	do {
		print "\nHow many ReplayTV's do you want to use with $program_title?\n[default: 1] > ";
		$inp_replaynum = int <STDIN>;		
		if ($inp_replaynum == 0) {
			$inp_replaynum = 1;
		}
		if (($inp_replaynum > 0) && ($inp_replaynum < 99)) {
			$choiceok = 1;
		}
	} while ($choiceok < 1);

	$ctr = 1;
	do {
		print "\n\nReplay Number $ctr:\n";
		
		$choiceok = 0;
		do {
			if ($ctr == 1) {
				print "(This will be used as the default unit)\n";
			}

			print "\nWhat is the FQDN or IP address of this unit [eg. 192.168.0.1]?\n> ";
			$inp_unitip = <STDIN>;
			$inp_unitip =~ s/\r//g;		# Eat LF
			$inp_unitip =~ s/\n//g;		# Eat CR

			if (length($inp_unitip) > 0) {
				$choiceok = 1;
			}
		} while ($choiceok < 1);

		print "\nWhat http port does it use [default: 80]?\n> ";
		$inp_unitport = <STDIN>;
		$inp_unitport =~ s/\r//g;	# Eat LF
		$inp_unitport =~ s/\n//g;	# Eat CR

		if (length($inp_unitport) > 0) {
			$inp_unitport = int $inp_unitport;
		} else {
			$inp_unitport = 80;
		}

		$choiceok = 0;
		do {
			print "\nWhat is the network name of this unit [eg. Bedroom]?\n> ";
			$inp_unitname = <STDIN>;
			$inp_unitname =~ s/\r//g;	# Eat LF
			$inp_unitname =~ s/\n//g;	# Eat CR

			if (length($inp_unitname) > 0) {
				$choiceok = 1;
			}
		} while ($choiceok < 1);

		$choiceok = 0;
		do {
			print "\nWhat quality level would you like (S)tandard, M)edium, H)igh)?\n[default: S] > ";
			$inp_quality = uc <STDIN>;
			$inp_quality =~ s/\r//g; # Eat LF
			$inp_quality =~ s/\n//g; # Eat CR
	
			if (length($inp_quality) < 1) {
				$inp_quality = 2;
			}
			if ($inp_quality =~ 'S') {
				$inp_quality = 2;
			}
			if ($inp_quality =~ 'M') {
				$inp_quality = 1;
			}
			if ($inp_quality =~ 'H') {
			$inp_quality = 0;
			}
			if (($inp_quality > -1) && ($inp_quality < 3)) {
				$choiceok = 1;
			}
		} while ($choiceok < 1);

		$choiceok = 0;
		do {
			print "\nHow many episodes would you like to keep?\n[default: 1] > ";
			$inp_keep = int <STDIN>;		
			if ($inp_keep == 0) {
				$inp_keep = int 1;
			}
			if (($inp_keep > 0) && ($inp_keep < 10)) {
				$choiceok = 1;
			}
		} while ($choiceok < 1);

		if ($ctr == 1) {
			$replayunits = "$inp_unitip,$inp_unitport,$inp_unitname,$inp_quality,$inp_keep";
			$defaultreplaytv = $inp_unitip;
		}else{
			$replayunits .= ";$inp_unitip,$inp_unitport,$inp_unitname,$inp_quality,$inp_keep";
		}
		
		$ctr++;

	} while ($ctr < $inp_replaynum + 1);
}

print "\n";

writeDebug("Interactive Mode Completed");

#-------------------------------------------------------------------
# Clean ReplayTV Database
#-------------------------------------------------------------------

if ($do_not_drop_rows) {
	writeDebug("Skipping Row Delete");
}else{
	writeDebug("Purging old data from database");

	$Stmt = "DELETE FROM $db_table_replayunits;";
	if (sqlStmt($DSNLink,$Stmt)) {
		writeDebug("Table $db_table_replayunits purged");			
	}else{
		writeDebug("Failed: " . &GetLastSQLError() . " (" &GetLastSQLStmt() . ")");
		abend("Failed to purge table $db_table_replayunits");
	}

	writeDebug("Purge Complete");

}

#-------------------------------------------------------------------
# Insert Rows
#-------------------------------------------------------------------

$rows = 0;

if ($do_not_insert) {
	writeDebug("Database Insert Disabled");
}


for ( split /;/, $replayunits ) {
	/;/;
	($rtv_unit,$rtv_port,$rtv_label,$rtv_quality,$rtv_keep) = split(',', $_, 5);
	if ($do_not_insert) {
		writeDebug(">> $rtv_label ($rtv_unit:$rtv_port) [$rtv_quality, $rtv_keep]");
	}else{
		if (insertRTVRow($rtv_label,$rtv_unit,$rtv_port,$rtv_quality,$rtv_keep)) {
			$rows++;
		}
	}
}

writeDebug("$rows added to $db_table_replayunits table.");


$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Terminating Database Connection from $DATASOURCE{DSN} ($DSNLink)");
endDSN("",$DSNLink);
writeDebug("Job finished at $now ($runtime seconds)");

writeDebug("********************************************************");


#-------------------------------------------------------------------
sub insertRTVRow {
	#
	# Inserts a Row Into the ReplayUnits DB 
	#
	#-----------------------------------------------------------------------------
	my $replayname = shift;
	my $replayaddress = shift;
	my $replayport = int shift;
	my $replayquality = int shift;
	my $replaykeep = int shift;

	my $FieldNames = "";
	my $FieldValues = "";
	
	$FieldNames = $null;
	$FieldNames .= "replayname, replayaddress, replayport, ";
	$FieldNames .= "defaultquality, defaultkeep, lastsnapshot";
 
	$FieldValues = $null;
	$FieldValues .= "'$replayname', '$replayaddress', $replayport, ";
	$FieldValues .= "$replayquality, $replaykeep, 0";
 
	$Stmt = "INSERT INTO $db_table_replayunits ($FieldNames) VALUES ($FieldValues);";
 	
	if (sqlStmt($DSNLink,$Stmt)) {
 		return 1;
	}else{
		return 0;
	}

}
