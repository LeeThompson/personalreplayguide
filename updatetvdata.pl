#!/usr/bin/perl
#
# Personal ReplayGuide DataFeed Client
# by Lee Thompson <thompsonl@logh.net>
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

my $_version = "Personal ReplayGuide|DataFeed Update Client|1|0|22|Lee Thompson";

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
# Debug Options
#-----------------------------------------------------------------------------------

$abort = 0;
$debug = 0;
$verbose = 1;				# Talky

#-----------------------------------------------------------------------------------
# Set Required Defaults
#-----------------------------------------------------------------------------------

$datafeed_client = "";
$datafeed_converter = "";
$datafeed_parameters = "";
$datafeed_redirectoutput = 0;
$datafeed_success = 1;
$datafeed_geticons = 0;
$datafeed_geticonscript = "./getchannelicons.pl";

$configfile = "updatetvdata.conf";				# This is optional
$configstatus = getConfig($configfile);				# Read Configuration
$configstatus = getConfig($datafeed);				# Load data feed settings
 
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

my $current_path = getcwd;

(my $xmlfile_path, my $xmlfile_filename) =  getPathAndFile($cnf_xmlfile);


if ($xmlfile_path eq ".") {
	$xmlfile_path = $current_path;
}



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

$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );
$started = time;

#-------------------------------------------------------------------
# Final Checks
#-------------------------------------------------------------------

if ($datafeed eq $null ) {
	abend("No datafeed specified.  Check prg.conf or INSTALL.txt");
}

if ($datafeed_client eq $null ) {
	abend("No datafeed client specified for $datafeed");
}

if ($datafeed_converter eq $null ) {
	abend("No datafeed converter specified for $datafeed");
}


writeDebug("Job started at $now");


#-------------------------------------------------------------------
# Calculate Estimates for TV Data Download Time
#
# These are based on a typical digital cable lineup of 170 channels.
#
#-------------------------------------------------------------------

$timeestimate = 0;

if ($datafeed eq "xmltv") {
	(my $junk, $days) = split(/--days/,$datafeed_parameters,2);
	$days = int $days;

	if ($days < 1) {
		$days = 7;
		writeDebug("Could not find the number of days specified for XMLTV, assuming $days.");
	}
	
	$timeestimate = $timeestimate + ($days * 11.50);
}

if ($datafeed eq "datadirect") {
	getConfig("datadirect",1,"days");
	
	$timeestimate = $timeestimate + ($days * 0.50);

}

(my $datafeed_path, my $datafeed_filename) =  getPathAndFile($datafeed_client);

#-----------------------------------------------------------------------------------
# Download New Listing Data
#-----------------------------------------------------------------------------------

$prefix = "";
if ($datafeed_filename =~ /\.pl/) {
	$prefix = $^X;
	if ($prefix =~ /\.dll/i) {
		$prefix = "";
	}
}

$client_cmd = "$prefix $datafeed_filename";

if (length($datafeed_parameters) > 0) {
	$client_cmd .= " $datafeed_parameters";
}

if ($datafeed_redirectoutput) {
	$client_cmd .= " > $xmlfile_path/$xmlfile_filename";
}

if ($client_cmd eq "") {
	abend("No client specified.  ($datafeed_client; $datafeed_path, $datafeed_filename)");
}

writeDebug("Calling Datafeed Client for $datafeed.");
writeDebug("Client: $client_cmd");
writeDebug("Depending on the speed of the machine and internet connection this may take approximately $timeestimate minutes.");


my $dir_changed = 0;

if ($datafeed_path ne ".") {
	if ($datafeed_path ne "") {
		chdir $datafeed_path;
		$dir_changed = 1;
	}
}

$client_start = time;
my $result = system("$client_cmd");
$client_finish = time;
$client_seconds = $client_finish - $client_start;
$client_minutes = int ($client_seconds / 60);

if ($dir_changed) {
	chdir $current_path;
	undef $dir_changed;
}

if ($result == -1) {
	writeDebug("Could not execute $datafeed_filename.  Check file permissions.");
	$retval = 1;
}else{
	#-----------------------------------
	# Get the exit value from client
	#-----------------------------------

	$retval = $? >> 8;

	if ($retval == $datafeed_success ) {
		writeDebug("Client for $datafeed was successful. ($retval)");
		writeDebug("Client for $datafeed took $client_minutes minutes to download TV data.");
	}else{
		writeDebug("Client for $datafeed failed. ($retval) ");
		$abort = 1;
	}
}

if ($datafeed_converter eq $null ) {
	writeDebug("No datafeed converter specified for $datafeed");
	$abort = 1;
}


#-----------------------------------------------------------------------------------
# Run Converter
#-----------------------------------------------------------------------------------

if (!$abort) {
	
	(my $datafeed_path, my $datafeed_filename) =  getPathAndFile($datafeed_converter);

	my $dir_changed = 0;

	$prefix = "";
	if ($datafeed_filename =~ /\.pl/) {
		$prefix = $^X;
		if ($prefix =~ /\.dll/i) {
			$prefix = "";
		}
	}

	$converter_cmd = "$prefix $datafeed_filename";

	if ($converter_cmd eq "") {
		writeDebug("Warning: No converter specified.  ($datafeed_converter; $datafeed_path, $datafeed_filename)");
	}

	writeDebug("Calling Datafeed Converter for $datafeed.");
	writeDebug("Converter: $converter_cmd");

	if ($datafeed_path ne ".") {
		if ($datafeed_path ne "") {
			chdir $datafeed_path;
			$dir_changed = 1;
		}
	}

	$convert_start = time;
	my $result = system("$converter_cmd");	
	$convert_finish = time;
	$convert_seconds = $convert_finish - $convert_start;
	$convert_minutes = int ($convert_seconds / 60);

	if ($dir_changed) {
		chdir $current_path;
		undef $dir_changed;
	}

	if ($result == -1) {
		writeDebug("Could not execute $datafeed_filename.  Check file permissions.");
		$retval = 1;
	}else{
		#-----------------------------------
		# Get the exit value from converter
		#-----------------------------------

		$retval = $? >> 8;

		if ($retval == 255) {
			writeDebug("Converter for $datafeed failed. ($retval)");
			$abort = 1;	
		}elsif ($retval) {
			writeDebug("Converter for $datafeed was successful. ($retval)");
			writeDebug("Converter for $datafeed took $convert_minutes minutes to process TV data.");
		}else{
			writeDebug("Converter for $datafeed failed. ($retval)");
			$abort = 1;
		}
	}
}

#-----------------------------------------------------------------------------------
# Run Get Icons if requested
#-----------------------------------------------------------------------------------

if ((!$abort) && (length($datafeed_geticonscript) > 0)) {

	(my $datafeed_path, my $datafeed_filename) =  getPathAndFile($datafeed_geticonscript);

	$prefix = "";
	if ($datafeed_filename =~ /\.pl/) {
		$prefix = $^X;
		if ($prefix =~ /\.dll/i) {
			$prefix = "";
		}
	}

	$icon_cmd = "$prefix $datafeed_filename";

	if ($icon_cmd eq "") {
		writeDebug("Warning: No icon script specified.  ($datafeed_geticonscript; $datafeed_path, $datafeed_filename)");
	}

	writeDebug("Calling Icon Download Script for $datafeed.");
	writeDebug("Icons: $icon_cmd");

	my $dir_changed = 0;

	if ($datafeed_path ne ".") {
		if ($datafeed_path ne "") {
			chdir $datafeed_path;
			$dir_changed = 1;
		}
	}

	$icon_start = time;
	my $result = system("$icon_cmd");
	$icon_finish = time;
	$icon_seconds = $icon_finish - $icon_start;
	$icon_minutes = int ($icon_seconds / 60);

	if ($dir_changed) {
		chdir $current_path;
		undef $dir_changed;
	}

	if ($result == -1) {
		writeDebug("Could not execute $datafeed_filename.  Check file permissions.");
		$retval = 1;
	}else{
		# Get the exit value from client

		$retval = $? >> 8;

		if ($retval == 255) {
			writeDebug("Icon download for $datafeed failed. ($retval)");
			$abort = 1;	
		}elsif ($retval) {
			writeDebug("Icon download for $datafeed was successful. ($retval)");
			writeDebug("Icon download for $datafeed took $icon_minutes minutes to locate icons.");
		}else{
			writeDebug("Icon download for $datafeed failed. ($retval) ");
			$abort = 1;
		}
	}
}
	

#-----------------------------------------------------------------------------------
# Finish Up
#-----------------------------------------------------------------------------------

$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Job finished at $now ($runtime seconds)");

my $retcode = 0;

if (!$abort) {
	writeDebug("DataFeed Update Successful");
	$retcode = 1;
}else{
	writeDebug("DataFeed Update Failed");
	$retcode = 0;
}


&ShowHTTPFooter;

writeDebug("********************************************************");

exit($retcode);


