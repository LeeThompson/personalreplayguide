#!/usr/bin/perl
#
# Personal ReplayGuide SQL Converter
# by Lee Thompson <thompsonl@logh.net>
#
# Requirements: 
#	DataDirect Service
#
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
#
# Zap2It DataDirect Service
#
# Use of DataDirect with Personal ReplayGuide is free, although you will need to 
# fill out a quarterly survey for Zap2It (Tribune Media Services).
#
# To sign up for the service, please visit http://datadirect.zap2it.com and click
# to use the DataDirect service for free.    It's fairly short and largely 
# related to PVRs and television anyway.  
#
# The DataDirect Personal ReplayGuide/ReplaySchedule Certificate Code is:
# DGYM-ZKZM-CBUT
#
# All users and developers for Personal ReplayGuide may use this certificate code.
# (Including replaySchedule).
#
# NOTE TO DEVELOPERS: DO NOT use the certificate code within this document for non
# Personal ReplayGuide projects.   Instead please write to labs@zap2it.com and request
# your own certificate code.
#
#-----------------------------------------------------------------------------------
# NOTE: If you select multiple lineups that have the same feeds (like two SCIFIPs)
#       the lowest channel number will appear.
#-----------------------------------------------------------------------------------

use POSIX qw( strftime getcwd );
use English;
use Time::Local;
use SOAP::Lite; 
use Unicode::String;
use bytes;
Unicode::String->stringify_as( 'latin1' ); 

require LWP::Simple;
require LWP::UserAgent;
require HTTP::Request;
require HTTP::Headers;

my $_version = "Personal ReplayGuide|DataDirect Client|1|0|24|Lee Thompson";

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
# Set Defaults and Read Config
#-----------------------------------------------------------------------------------

$retcode = 0;
$htmlmode = 0;
$webservice = "http://docs.tms.tribune.com/tech/tmsdatadirect/zap2it/xtvd.wsdl";
$username = "username";				# Username for DataDirect
$password = "password";				# Password for DataDirect
$days = 3;					# Default Days to Download
$verbose = 1;					# If this is zero, run silently
$cnf_xmlfile = "./na.xml";			# Output File
$configfile = "datadirect.conf";		# This is optional
$configstatus = getConfig($configfile);		# Read Configuration

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

$starttime_seconds = as_epoch_seconds(strftime( "%Y%m%d%", gmtime ) . "000000" );
$endtime_seconds = $starttime_seconds + ((($days * 24) * 60) * 60);

$starttime_ts = as_time_string($starttime_seconds);
$endtime_ts = as_time_string($endtime_seconds);

$starttime = substr($starttime_ts,0,4) . "-" . substr($starttime_ts,4,2) . "-" . substr($starttime_ts,6,2)  . "T" . substr($starttime_ts,8,2) . ":" . substr($starttime_ts,10,2) . ":" . substr($starttime_ts,12,2) . "Z";
$endtime = substr($endtime_ts,0,4) . "-" . substr($endtime_ts,4,2) . "-" . substr($endtime_ts,6,2)  . "T" . substr($endtime_ts,8,2) . ":" . substr($endtime_ts,10,2) . ":" . substr($endtime_ts,12,2) . "Z";

writeDebug("Job started at $now");
writeDebug("Requesting up to $days days of data from DataDirect");

if ($debug) {
	writeDebug("DEBUG: Range is $starttime - $endtime");
}

if ($debug) {
	writeDebug("DEBUG: Account: $username  Password: $password");
}

writeDebug("Building SOAP Object for $webservice");

$soapenv = SOAP::Lite
 -> service($webservice)
 -> outputxml('true')
 -> on_fault( sub { 
	my($soap,$res)=@_; 
	writeDebug("FATAL ERROR - SOAP call failed: " . 
	(ref $res ? $res->faultstring : $soap->transport->status)); 
	exit 1; 
	} );

writeDebug("SOAP Object Completed");

writeDebug("Starting Data Download");


$xtvddoc = $soapenv
  -> proxy('http://notused/', options => {compress_threshold => 10000}, timeout => 420)
  -> download("<startTime>$starttime</startTime><endTime>$endtime</endTime>");

writeDebug("Data Download Complete");

$accessdenied = 0;
$message = "";

writeDebug("Converting to UTF8");

$xtvddoc = Unicode::String::utf8( $xtvddoc );

writeDebug("Conversion Complete");

writeDebug("Checking for Errors");

if ($xtvddoc =~ "<HTML><HEAD><TITLE>401") {
	writeDebug("FATAL ERROR - DataDirect->Access Denied");
	$accessdenied = 1;
	$xtvddoc = "";
}

if ($xtvddoc =~ "<HTML><HEAD><TITLE>500") {
	writeDebug("FATAL ERROR - DataDirect->Server Error");
	$message = $xtvddoc;
	$message =~ s/.*<PRE>([^<]*)\W.*/$1/;
	if ($message eq $xtvddoc) {
		$message = "";
	}
	$xtvddoc = "";
}

if ($xtvddoc =~ "<HTML><HEAD><TITLE>") {
	writeDebug("FATAL ERROR - DataDirect: Unknown Error");
	$xtvddoc = "";
}

writeDebug("Check Complete");

writeDebug("Looking for Data Block");

if ($xtvddoc =~ m#(<xtvd\s.*</xtvd>)#s) {
	writeDebug("Found Data Block");

	writeDebug("Writing Data");

	if (open(HOUTPUT,">$cnf_xmlfile")) {
		binmode HOUTPUT;
		print HOUTPUT $xtvddoc;
		close HOUTPUT;
		writeDebug("Wrote data successfully to \"$cnf_xmlfile\".");
	}else{
		writeDebug("Attempt to write data to \"$cnf_xmlfile\" failed.");
	}

	$exitflag = 0;

	if(open(HINPUT,"<$cnf_xmlfile")) {
		do {
			$line = readline HINPUT;
			chomp($line);
			if ($line =~ /message/) {
				$message = $line;
				$message =~ s/.*<message>([^<]*)\W.*/$1/;
				if ($message eq $line) {
					$message = "";
				}
			}
			if ($line =~ /faultstring/) {
				$message = $line;
				$message =~ s/.*<faultstring>([^<]*)\W.*/$1/;
				if ($message eq $line) {
					$message = "";
				}
				$exitflag = 1;
			}
	
			if ($line =~ /<\/messages>/) {
				$exitflag = 1;
			}
			if ($line =~ /<messages\/>/) {
				$message = "";
				$exitflag = 1;
			}
		} until ($exitflag > 0);

		close HINPUT;

		if (length($message) > 0) {
			writeDebug("From DataDirect: $message");
			$message = "";
		}else{
			writeDebug("No alerts or messages from DataDirect");
			$retcode = 1;
		}

	}
	


}else{
	writeDebug("No Data Block");

	if (!$accessdenied) {
		if (length($message) > 0) {
			writeDebug("$message");
		}else{
			writeDebug("Error: $xtvddoc");
		}
	}else{
		writeDebug("Access was denied");
	}
}

$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Job finished at $now ($runtime seconds)");

&ShowHTTPFooter;

writeDebug("********************************************************");

exit($retcode);

#----------------------------------------------------
sub SOAP::Transport::HTTP::Client::get_basic_credentials {
	#
	# Callback for HTTP Login Info
	#
	# ------------------------------------------------------------------------------
	return "$username" => "$password";
}

