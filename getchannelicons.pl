#!/usr/bin/perl
#
#------------------------------------------------------------------------------------
#  $Id: getchannelicons.pl,v 1.3 2003/07/19 13:34:39 pvanbaren Exp $
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

use POSIX qw( strftime getcwd );

#-------------------------------------------------------------
# Subclass LWP::UserAgent to permit redirected POST methods
#-------------------------------------------------------------

package RedirectUserAgent;
use LWP::UserAgent;
@ISA = qw(LWP::UserAgent);
sub redirect_ok { 1; }

package main;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common;

my $_version = "Personal ReplayGuide|Get Channel Icons|1|0|23|J.M.,Philip Van Baren,Lee Thompson";

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

require 'rg_config.pl';			# Load config functions
require 'rg_common.pl';			# Load common functions
require 'rg_database.pl';		# Load database functions
require 'rg_info.pl';			# Database Info

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

$providerid = 0;
$zipcode = 0;
$channelicondir = "";

$debug = 0;					# Debug Output
$verbose = 1;					# Verbose Output
$configfile = "getchannelicons.conf";		# This is optional
$configstatus = &getConfig($configfile);	# Read Configuration

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
writeDebug("$program_title\:$program_module v$program_version (Build $program_build) $script_pathname");
writeDebug("Running as $script_pathname with PID $$");
writeDebug("Remote Address: $RemoteAddress");
if ($verbose) {
	writeDebug("Console Output: Enabled");
}else{
	writeDebug("Console Output: Disabled");
}

identifyLoadedModules();

if ($debug) {
	writeOutput("Debug Messages are ON");
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


$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );
$started = time;


writeDebug("Job started at $now");

$defaultproviderid = $providerid;
$defaultzipcode = $zipcode;

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

#-------------------------------------------------------------------
# Get Channel Icons
#-------------------------------------------------------------------

$Stmt = "";
$Stmt .= "SELECT * ";
$Stmt .= "FROM $db_table_channels ";
$Stmt .= "WHERE hidden = 0 ";
$Stmt .= "ORDER BY postalcode, lineupname, lineupdevice;";

$records = 0;

$sth = sqlStmt($DSNLink,$Stmt);
if ( $sth ) {
	while ( $row = $sth->fetchrow_hashref ) {
		$tmsid = $row->{'tmsid'};

		$channel_iconsrc = $row->{'iconsrc'};

		#-------------------------------------------------------------
		# Only do the work if there is not an icon defined.
		#-------------------------------------------------------------

		if (( $tmsid ) && ( length($channel_iconsrc) == 0)) {
	
			#-------------------------------------------------------------
			# Should be a Data Direct populated DB...
			# We have to add the channel icons to the DB on our own by 
			# scraping Zap2It.
			#-------------------------------------------------------------
			
			$channel_postalcode = $row->{'postalcode'};
			$channel_lineupname = $row->{'lineupname'};
			$channel_lineupdevice = $row->{'lineupdevice'};
	
			#-------------------------------------------------------------
			# If the extended lineup fields aren't populated, just go 
			# with defaults, otherwise attempt to calculate the providerid
			#-------------------------------------------------------------

			if (length($channel_postalcode) > 0) {
				$currentlineup = "$channel_postalcode $channel_lineupname $channel_lineupdevice";
			}else{
				$zipcode = $defaultzipcode;
				$providerid = $defaultproviderid;
				$currentlineup = "";
				$prevlineup = "";
			}

			if ($currentlineup ne $prevlineup) {
				$iconlist = "";

				writeDebug("Lineup: $currentlineup");

				$channel_providerid = getProviderID($channel_postalcode,$channel_lineupname,$channel_lineupdevice);

				writeDebug("getProviderID returned $channel_providerid");

				if ($channel_postalcode ne $null) {
					$zipcode = $channel_postalcode;
				}else{
					$zipcode = $defaultzipcode;
					writeDebug("Using default zipcode ($zipcode)");
				}

				if ($channel_providerid != 0) {
					$providerid = $channel_providerid;
				}else{
					$providerid = $defaultproviderid;
					writeDebug("Using default providerid ($providerid)");
				}
	
			}

	
			#-------------------------------------------------------------
			# Try to get an icon.   If providerid is 0 or zipcode is null
			# getChannelIconURL will return null immediately.
			#-------------------------------------------------------------

			$channel_iconsrc = getChannelIconURL($tmsid);
	
			if ( $channelicondir ) {
				downloadChannelIcon($channel_iconsrc);
			}

			if (length($channel_iconsrc) > 0) {
				#-------------------------------------------------------------
				# If we got an icon, update the table.
				#-------------------------------------------------------------

				$channel_iconsrc = filterfield($channel_iconsrc);

				my $db_handle = &StartDSN;
	
				my $Stmt = "UPDATE $db_table_channels SET iconsrc = '$channel_iconsrc' WHERE tmsid = '$tmsid';";

				if ( sqlStmt($db_handle,$Stmt) ) {
					writeDebug("$tmsid: Updated with $channel_iconsrc");
					$records++;
				} else {
					writeDebug("Attempt to update table $db_table_channels Failed: " . &GetLastSQLError()); 
					abend("Failed to update table: $db_table_channels.");
				}

				endDSN("",$db_handle);
				undef $Stmt;
			}else{
				writeDebug("$tmsid: Could not find an icon");
			}

		} else {

			#-------------------------------------------------------------
			# Probably an XMLTV populated DB...
			# The channel icons should already be in the DB.
			#-------------------------------------------------------------
		
			$channel_iconsrc = $row->{'iconsrc'};
			if ( $channelicondir ) {
				downloadChannelIcon($channel_iconsrc);
			}
		}

		$prevlineup = $currentlineup;
	}
}else{
	abend("Error getting icons");
	$retcode = 0;
}


if ($records > 0) {
	$retcode = 1;
}

writeDebug("$records icons added");

$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Terminating Database Connection from $DATASOURCE{DSN} ($DSNLink)");

endDSN($sth,$DSNLink);

writeDebug("Job finished at $now ($runtime seconds)");

&ShowHTTPFooter;

writeDebug("********************************************************");

exit($retcode);

#----------------------------------------------------------------------------
sub getProviderID {
	#
	# Gets the provider list and tries to match it with the arguments passed in
	# (PostalCode,LineupName,LineupDevice)
	#
	# Returns providerid or 0.	
	#
	# ------------------------------------------------------------------------------

	my $postalcode = shift;
	my $lineupname = shift;
	my $lineupdevice = shift;
	my $providerid = 0; 
	my $buffer = "";
	my $specialdebug = 0;
	
	my $ua = RedirectUserAgent->new(
 		cookie_jar => HTTP::Cookies->new(),
		);

    	my $req = POST('http://tvlistings2.zap2it.com/zipcode.asp?partner_id=national&zipcode=$postalcode',
		[
		zipcode => "$postalcode",
		partner_id => "national",
		FormName => "zipcode.asp",
		]);

	if ($debug) {
		writeDebug("getProviderID::Connecting to Zap2It... ",1);
	}
	
  	my $res = $ua->request($req);
 
 	if ($debug) {
		writeDebug("Done!");
	}
	
  	if ($debug) {
  		writeDebug(" REQUEST: $req->as_string");
		writeDebug("RESPONSE: $res->as_string");
  	}

	$buffer = $res->content();

	if ( $buffer =~ /\<select name=\"provider\" size=\"4\"\>/i ) {

		(my $junk, my $option1, my $junk2) = split ( /\<select name=\"provider\" size=\"4\"\>/i, $buffer, 3);
		(my $optionlist, my $junk3) = split ( /\<\/select\>/, $option1, 2);

		$optionlist =~ s/\&nbsp;//g;
		my @options = split(/\<\/option\>/,$optionlist);

		foreach my $option ( @options ) {
			(my $optionvalue,my $optiondesc) = split(/\>/,$option);
			my $optionid = $optionvalue;
			$optionid =~ s/.*<option value=\"([^\"]*).*/$1/;
			(my $o_lineup,my $o_city,my $o_device) = split(/ - /,$optiondesc);
		
			if ($specialdebug) {
				writeDebug("$optionid: $o_lineup,$o_city,$o_device");
			}

			if ($specialdebug) {
				writeDebug("Checking " . substr($lineupname,0,31) . "==" . substr($o_lineup,0,31) . "?");
			}

			if (substr($lineupname,0,31) eq substr($o_lineup,0,31)) {
				if ($specialdebug) {
					writeDebug("Checking " . substr($lineupname,0,31) . "==" . substr($o_lineup,0,31) . " MATCH");
				}

				if ($specialdebug) {
					writeDebug("Checking " . substr($lineupdevice,0,31) . "==" . substr($o_device,0,31) . "?");
				}
				if (substr($lineupdevice,0,31) eq substr($o_device,0,31)) {
					if ($specialdebug) {
						writeDebug("Checking " . substr($lineupdevice,0,31) . "==" . substr($o_device,0,31) . " MATCH ($optionid)");
					}

					$providerid = $optionid;
				}
			}
		}
	}

	return $providerid;
}

#----------------------------------------------------------------------------
sub GetChannelIconList {
	#
	# Returns one day's worth of listings from Zap2It from which to scrape icons
	#
	# ------------------------------------------------------------------------------
	
# Code below only works on Perl 5.8+ so we use RedirectUserAgent, a subclassed LWP::UserAgent
#	my $ua = LWP::UserAgent->new(
#		requests_redirectable => ['GET', 'HEAD', 'POST'],
# 		cookie_jar => HTTP::Cookies->new(),
#		);

	my $ua = RedirectUserAgent->new(
 		cookie_jar => HTTP::Cookies->new(),
		);

    	my $req = POST('http://tvlistings2.zap2it.com/system.asp?partner_id=national&zipcode=$zipcode&id=form1&name=form1',
		[
		provider => "$providerid",
		zipcode => "$zipcode",
		FormName => "system.asp",
		page_from => "",
		saveProvider => "See Listings"
		]);

	if ($debug) {
		writeDebug("GetChannelIconList::Connecting to Zap2It... ",1);
	}
	
  	my $res = $ua->request($req);
 
 	if ($debug) {
		writeDebug("Done!");
	}
	
  	if ($debug) {
  		writeDebug(" REQUEST: $req->as_string");
		writeDebug("RESPONSE: $res->as_string");
  	}
  
	#-----------------------------------------
	# Get the all the values for current time
	#-----------------------------------------
	my ($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time);

	#-----------------------------------------
	# Increment the month by 1 because in Perl months of the year are zero-based
	#-----------------------------------------

	my $RealMonth = $Month + 1;

	#-----------------------------------------
	# Add 1900 to the year because in Perl 
	# year  is reported as the number of years
	# since 1900.
	#-----------------------------------------

	my $Fixed_Year = $Year + 1900;

    	$req = POST('http://tvlistings2.zap2it.com/listings_redirect.asp?partner_id=national&id=form1&name=form1',
		[
		displayType => "Grid",
		duration => "1",
		startDay => "$RealMonth/$Day/$Fixed_Year",
		startTime => "0",
		category => "0",
		station => "0",
		rowdisplay => "0",
		goButton => "GO"
		]);
		
	if ($debug) {
		writeDebug("GetChannelIconList::Retrieving icon listing... ",1);
	}
	
  	$res = $ua->request($req);

 	if ($debug) {
		writeDebug("Done!");
	}
	
  	if ($debug) {
  		writeDebug(" REQUEST: $req->as_string");
		writeDebug("RESPONSE: $res->as_string");
  	}
    	
    	return $res->content();
}

#----------------------------------------------------------------------------
sub getChannelIconURL {
	#
	# Get URL of Channel Icon (TMS Channel ID)
	# 
	# Returns (Icon URL)
	#
	# ------------------------------------------------------------------------------
	
	my $tmsid = shift;
	my $channel_iconsrc = "";

	if (($providerid eq $null) || ($zipcode eq $null) || ($providerid == 0)) {
		#-----------------------------------------------------
		# Absolutely no reason to do anything
		#-----------------------------------------------------

		return;
	}
	
	#--------------------------------------------------------
	# Only get the listings page from Zap2It once per lineup
	#--------------------------------------------------------

	if ($iconlist eq "") {
 		$iconlist = &GetChannelIconList;
 	}
 	
	if ( $iconlist =~ /<img src="(.*)"><br>\s*<b><a href="listings_redirect.asp\?station_num=$tmsid/i ) {
		$channel_iconsrc = "http://tvlistings2.zap2it.com$1";
		if ($debug) {
			writeDebug("getChannelIconURL::Channel ID: $tmsid\nIcon: $channel_iconsrc");
			if (!$channelicondir) {
				# 
			}
		}
	} else {
		$channel_iconsrc = "";
		if ($debug) {
			writeDebug("getChannelIconURL::Channel ID: $tmsid\nIcon: not found");
		}
	}

	return $channel_iconsrc;
}

#----------------------------------------------------------------------------
sub downloadChannelIcon {
	#
	# Download Channel Icon (Icon URL)
	#
	# ------------------------------------------------------------------------------
	
	my $channel_iconsrc = shift;
	if( $channel_iconsrc ) {
		if ($debug) {
			writeDebug("downloadChannelIcon::Fetching icon... ",1);
		}
		my $filename = (reverse split(/\//,$channel_iconsrc))[0];
		if ( is_error( getstore($channel_iconsrc, "$channelicondir/$filename") ) ) {
			if ($debug) {
				writeDebug("Error!");
			}
		} else {
			if ($debug) {
				writeDebug("Done!");
			}
		}
	}

	return 1;
}


