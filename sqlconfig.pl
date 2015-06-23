#!/usr/bin/perl
#
# Personal ReplayGuide Configuration Utility
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
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

use POSIX qw( strftime getcwd );
use English;
use Time::Local;
require LWP::Simple;
require LWP::UserAgent;
require HTTP::Request;
require HTTP::Headers;

my $_version = "Personal ReplayGuide|SQL Configure|1|0|14|Lee Thompson,Kanji T. Bates";

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
$debug = 0;				# Debug Messages

#-----------------------------------------------------------------------------------
# Define Options
#-----------------------------------------------------------------------------------
$allow_create_database = 1;		


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
# Warn about DBMS packages that do not support ALTER TABLE
#----------------------------------------------------------------


if ($db_driver eq "SQLite") {
	print "\n";
	print "Warning! $db_driver does not support commands needed to update table so\n";
	print "         any data in any tables involved in an upgrade will be lost.\n";
	print "\n";
	print "         $db_driver will automatically create the database if it does not exist.\n";
	$allow_create_database = 0;
}

if ($db_driver eq "ODBC") {
#	$allow_create_database = 0;
}

#----------------------------------------------------------------
# Gather Information
#----------------------------------------------------------------

$inp_dortv = 1;
$inp_createdb = 0;
$inp_isupgrade = "no";

if ($inp_dortv) {
	$choiceok = 0;
	do {
		print "\nIs this an upgrade?\n[default: no] > ";
		$inp_isupgrade = <STDIN>;
		$inp_isupgrade =~ s/\r//g;	# Eat LF
		$inp_isupgrade =~ s/\n//g;	# Eat CR		

		if ($inp_isupgrade =~ /Y/i) {
			$inp_isupgrade = 1;
		}else{
			$inp_isupgrade = 0;
		}
		if (($inp_isupgrade > -1) && ($inp_isupgrade < 2)) {
			$choiceok = 1;
		}
	} while ($choiceok < 1);

	if ((!$inp_isupgrade) && ($allow_create_database)) {
		$choiceok = 0;
		do {
		print "\nCreate the $db_name database?\n[default: no] > ";
			$inp_createdb = <STDIN>;
			$inp_createdb =~ s/\r//g;	# Eat LF
			$inp_createdb =~ s/\n//g;	# Eat CR		

			if ($inp_createdb =~ /Y/i) {
				$inp_createdb = 1;
			}
			if (($inp_createdb > -1) && ($inp_createdb < 2)) {
				$choiceok = 1;
			}
		} while ($choiceok < 1);

	}

}

print "\n\n";

writeDebug("Interactive Mode Completed");
writeDebug("Option Selected: isupgrade: $inp_isupgrade");
if ($allow_create_database) {
	writeDebug("Option Selected: createdb: $inp_createdb");
}

#-------------------------------------------------------------------
# Create Database (Untested)
#-------------------------------------------------------------------

if ($inp_createdb) {
	writeDebug("Creating Database ($db_name)");

	$retcode = CreateDatabase();

	&InitDSN;

	$db_link = &StartDSN;
	$sth = sqlStmt($db_link,"CREATE DATABASE $db_name;");
	endDSN($sth,$db_link);

}

&InitDSN;

#-------------------------------------------------------------------
# Start Database
#-------------------------------------------------------------------

$DSNLink = &StartDSN;

if ($DSNLink ne $null) {
	writeDebug("Database Connection Established to $DATASOURCE{DSN} using handle $DSNLink");
}else{
	writeDebug("Attempt to Connect to $DATASOURCE{DSN} Failed: " . &GetLastSQLError()); 
	writeDebug("Make sure $db_name database or ODBC DSN exists and check prg.conf [database] section!");
	abend("Could not establish database connection!");
}




#-------------------------------------------------------------------
# Create Tables
#-------------------------------------------------------------------

if (!$inp_isupgrade) {

	$sql_scriptname = "tvlistings";
	$sql_type = "";

	if ($db_driver eq "ODBC") {
		$sql_type = "mssql";
	}

	if ($db_driver eq "mysql") {
		$sql_type = "mysql";
	}

	if ($db_driver eq "SQLite") {
		$sql_type = "sqlite";
	}

	if ($sql_type eq "") {
		writeDebug("Error! $db_driver has not been tested with $program_title.  You will need to configure your database manually.");
		abend("Unsupported Driver");
	}

	$sql_scriptname .= "_$sql_type";
	$sql_scriptname .= ".sql";
	

	writeDebug("Creating Tables ($sql_scriptname)");

	$retcode = runSQLScript($sql_scriptname);

	if ($retcode) {
		writeDebug("Tables created successfully");
	}else{
		my $lastsqlerror = &GetLastSQLError();
		my $lastsqlstmt = &GetLastSQLStmt();
		writeDebug("Attempt to execute $sql_scriptname failed: $lastsqlerror ($lastsqlstmt)");
		abend("Aborted");
	}
}

#-------------------------------------------------------------------
# Update Tables
#-------------------------------------------------------------------

if ($inp_isupgrade) {
	$sql_scriptname = "update";
	$sql_type = "";

	if ($db_driver eq "ODBC") {
		$sql_type = "mssql";
	}

	if ($db_driver eq "mysql") {
		$sql_type = "mysql";
	}

	if ($db_driver eq "SQLite") {
		$sql_type = "sqlite";
		writeDebug("Warning! SQLite does not support ALTER TABLE.  Will DROP TABLE first.");
	}

	if ($sql_type eq "") {
		writeDebug("Error! $db_driver has not been tested with $program_title.  You will need to configure your database manually.");
		abend("Unsupported Driver");
	}

	$sql_scriptname .= "_$sql_type";
	$sql_scriptname .= ".sql";

	writeDebug("Updating Tables ($sql_scriptname)");

	$retcode = runSQLScript($sql_scriptname);

	writeDebug("runSQLScript returned $retcode");

	if ($retcode) {
		writeDebug("Tables updated successfully");
	}else{
		my $lastsqlerror = &GetLastSQLError();
		my $lastsqlstmt = &GetLastSQLStmt();
		writeDebug("Attempt to execute $sql_scriptname failed: $lastsqlerror ($lastsqlstmt)");
		abend("Aborted");
	}
}

#-------------------------------------------------------------------
# Finish Up
#-------------------------------------------------------------------

$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Terminating Database Connection from $DATASOURCE{DSN} ($DSNLink)");
endDSN("",$DSNLink);
writeDebug("Job finished at $now ($runtime seconds)");

writeDebug("********************************************************");

exit(1);
