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
require LWP::Simple;
require LWP::UserAgent;
require HTTP::Request;
require HTTP::Headers;

my $_version = "Personal ReplayGuide|DataDirect XML to SQL Converter|1|2|41|Lee Thompson";

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
$do_not_drop_rows = 0;			# Do not DELETE rows first
$do_not_insert = 0;			# Skip the DB insert
$verbose = 1;				# Talky


#-----------------------------------------------------------------------------------
# Set Required Defaults
#-----------------------------------------------------------------------------------

$scheduler = "rg_scheduler.pl";

# OS-Sensitive defaults

if ($^O eq 'MSWin32') {
	$schedule2sql = "schedule2sql.pl";
} else {
	$schedule2sql = "./schedule2sql.pl";
}

#-----------------------------------------------------------------------------------
# Define Options
#-----------------------------------------------------------------------------------

$show_episode_number = 1;
$show_first_aired_date = 1;
$retcode = 0;
$debug = 0;					# Debug Messages
$multiplier = 1000;				# Default Multiplier
$dotinterval = 500;				# Interval for the "." 
$maxrows = 0;					# Maximum Number of rows to INSERT
$cnf_xmlfile = "./na.xml";			# Data Direct file
$cnf_channelmap = "";				# Channel Mapping
$cnf_titlemap = "";				# Title Mapping
$use_castcrew = 1;				# Use Cast and Crew Data 
$configfile = "datadirect2sql.conf";		# This is optional
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

$rows = 0;
$dotctr = 0;
$emptystop = 0;
$lineup = 0;				# Lineup Number


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

writeDebug("Job started at $now");

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
	writeDebug("Attempt to Connect to $DATASOURCE{DSN} Failed: " . &GetLastSQLError());
	abend("Could not establish database connection!");
}


#-------------------------------------------------------------------
# Build Arrays
#-------------------------------------------------------------------

if (length($cnf_channelmap) > 0) {
	writeDebug("Loading channelmap from $cnf_channelmap");

	@channelmap = loadFile($cnf_channelmap);
	$cmap_ctr = countElements(@channelmap);

	if ($cmap_ctr > 0) {
		writeDebug("Found $cmap_ctr channel mappings.");
		$do_channelmap = 1;
	}else{
		writeDebug("No channel mappings found.");

	}
}

if (length($cnf_titlemap) > 0) {
	writeDebug("Loading titlemap from $cnf_titlemap");

	@titlemap = loadFile($cnf_titlemap);
	$tmap_ctr = countElements(@titlemap);

	if ($tmap_ctr > 0) {
		writeDebug("Found $tmap_ctr title mappings.");
		$do_titlemap = 1;
	}else{
		writeDebug("No title mappings found.");

	}
}

#-------------------------------------------------------------------
# Check Files
#-------------------------------------------------------------------

for ( split /,/, $cnf_xmlfile ) {
	/,/;
	$xml_file = $_;

	#-------------------------------------------------------------------
	# Open File
	#-------------------------------------------------------------------

	if (open(LISTINGS, "<$xml_file")) {
		writeDebug("Checking DataDirect Feed ($xml_file)");

		$exitflag = 0;
		$file_status = 0;
		$linetotal = 0;
		$scheduleline = 0;
		$endscheduleline = 0;
	
		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;
			if ($original_line =~ /<schedules>/) {
				$scheduleline = $linetotal;
			}
			if ($original_line =~ /<\/schedules>/) {
				$endscheduleline = $linetotal;
				$exitflag = 1;
				$file_status = 1;
			}
			if (eof(LISTINGS)) {
				$exitflag = 1;
			}
			$linetotal++;
			
		} until ($exitflag > 0);

		close LISTINGS;
	
		if (($endscheduleline - $scheduleline) < 2) {
			writeDebug("File $xml_file has an empty schedule block.");
			$file_status = 0;
		}
		
		if ($file_status < 1) {
			abend("File $xml_file does not contain schedule data, aborted.");
		}
			

	}else{
		abend("Could not open $xml_file");
	}
}

getConfig("datadirect",1,"days");
$timeestimate = 0;

#-------------------------------------------------------------------
# Calculate Estimates for Processing Time
#
# These are based on a typical digital cable lineup of 170 channels.
#
#-------------------------------------------------------------------
#
# If this process takes more than an hour with 12 days of listings
# on a modern machine you probably have data recovery/journaling/
# transaction logging running on the DBMS.   Turn it off, at least
# for PRG's database, you'll see an increase in speed by a factor
# of 10 or more.
#
#-------------------------------------------------------------------

if ($db_driver eq "ODBC") {
	#--------------------------------------------------
	# The ODBC driver is set to use TRUNCATE TABLE
	# which bypasses journaling.  
	#--------------------------------------------------

	$timeestimate = $timeestimate + ($days * 1.25);

	if ($use_castcrew) {
		$timeestimate = $timeestimate + ($days * 1.50);
	}

	$timeestimate = int $timeestimate;
}

if ($db_driver eq "mysql") {
	$timeestimate = $timeestimate + ($days * 0.25);

	if ($use_castcrew) {
		$timeestimate = $timeestimate + ($days * 0.25);
	}
}

if ($db_driver eq "SQLite") {	
	#--------------------------------------------------
	# If PRAGMA default_synchronous isn't set to OFF 
	# castcraw is 6.25 minutes per day of listings
	# tvlistings is 10.25 minutes per day of listings 
	#
	#--------------------------------------------------
	
	$timeestimate = $timeestimate + ($days * 0.25);

	if ($use_castcrew) {
		$timeestimate = $timeestimate + ($days * 0.50);
	}
}


writeDebug("Depending on the speed of the machine this may take approximately $timeestimate minutes.");


#-------------------------------------------------------------------
# Clean TVListings
#-------------------------------------------------------------------

if ($do_not_drop_rows) {
	writeDebug("Skipping Row Delete");
}else{

	writeDebug("Deleting Rows...");

	if ($db_driver eq "ODBC") {
		#----------------------------------------------------
		# MSSQL logs all transactions so DELETE will store a
		# complete copy of the table.  TRUNCATE gets around 
		# this buy just logging the event not the records.
		#----------------------------------------------------
		
		$Stmt = "TRUNCATE TABLE $db_table_tvlistings;";
	}else{
		$Stmt = "DELETE FROM $db_table_tvlistings;";
	}
	if (sqlStmt($prgdb_handle,$Stmt)) {
		writeDebug("Table $db_table_tvlistings purged");
	}else{
		my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
		abend("Failed: $sql_error");
	}

	if ($db_driver eq "ODBC") {
		$Stmt = "TRUNCATE TABLE $db_table_channels;";
	}else{
		$Stmt = "DELETE FROM $db_table_channels;";
	}

	if (sqlStmt($prgdb_handle,$Stmt)) {
		writeDebug("Table $db_table_channels purged");			
	}else{
		my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
		abend("Failed: $sql_error");
	}

	if ($db_driver eq "ODBC") {
		$Stmt = "TRUNCATE TABLE $db_table_castcrew;";
	}else{
		$Stmt = "DELETE FROM $db_table_castcrew;";
	}

	if (sqlStmt($prgdb_handle,$Stmt)) {
		writeDebug("Table $db_table_castcrew purged");			
	}else{
		my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
		abend("Failed: $sql_error");

	}

	writeDebug("Deleting Rows... Completed");			

}

#-------------------------------------------------------------------
# If INSERT is disabled, log data to a CSV
#-------------------------------------------------------------------

if ($do_not_insert) {
	open(CSVFILE, ">$db_table_tvlistings.csv");

	$FieldNames = "";
	$FieldNames .= "tmsprogramid, tmsid, ";
        $FieldNames .= "starttime, endtime, tuning, ";
	$FieldNames .= "channel, title, subtitle, ";
	$FieldNames .= "description, category, stereo, ";
	$FieldNames .= "captions, episodenum, vchiprating, ";
	$FieldNames .= "mpaarating, starrating, movieyear, ";
	$FieldNames .= "repeat, movie, subtitled, ";
	$FieldNames .= "advisories";

	print CSVFILE $FieldNames;
	print CSVFILE "\n";


	open(CSVFILE2, ">$db_table_channels.csv");

	$FieldNames = "";
	$FieldNames .= "tmsid, affiliate, ";
       	$FieldNames .= "tuning, displaynumber, channel, ";
	$FieldNames .= "display, iconsrc, hidden, ";
	$FieldNames .= "postalcode, systemtype, lineupname, ";
	$FieldNames .= "lineupdevice";

	print CSVFILE2 $FieldNames;
	print CSVFILE2 "\n";


	open(CSVFILE3, ">$db_table_castcrew.csv");

	$FieldNames = "";
	$FieldNames .= "tmsprogramid, role, ";
       	$FieldNames .= "surname, givenname";

	print CSVFILE3 $FieldNames;
	print CSVFILE3 "\n";


}


$iteration = 0;


for ( split /,/, $cnf_xmlfile ) {
	/,/;
	$xml_file = $_;
	$lineupnumber = 0;

	#-------------------------------------------------------------------
	# Open File
	#-------------------------------------------------------------------

	if (open(LISTINGS, "<$xml_file")) {
		writeDebug("$iteration: Reading DataDirect Feed ($xml_file)");
	}else{
		abend("Could not open $xml_file");
	}

	#-------------------------------------------------------------------
	# Convert XML to SQL
	#-------------------------------------------------------------------

	writeDebug("$xml_file: First Pass...");

		if ($verbose) {
			writeDebug("$xml_file: Seeking Stations Block");
		}

		#----------------------------------------
		# First we need to build an array of
		# stations and call letters
		#----------------------------------------

		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;

		} until ($original_line =~ /<stations>/);

		writeDebug("$xml_file: Parsing Stations");
		
		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;

			if ($line =~ /<station id=/) {
				$stationid = $line;
				$stationid =~ s/.*id='([^']*).*/$1/;
				$callsign = "";
				$name = "";
				$affiliate = "";
			}		
			if ($line =~ /<callSign>/) {
				$callsign = $line;
				$callsign =~ s/.*<callSign>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<name>/) {
				$name = $line;
				$name =~ s/.*<name>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<affiliate>/) {
				$affiliate = $line;
				$affiliate =~ s/.*<affiliate>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<\/station>/) {
				$stationarray{$stationid} = "$stationid\|$callsign\|$name\|$affiliate";
			}

		} until ($original_line =~ /<\/stations>/);


		writeDebug("$xml_file: Parsing Lineups");

		#----------------------------------------
		# Next we need the TMS Mapping
		#----------------------------------------

		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;

			if ($line =~ /<lineup /) {
				$lineupname = $line;
				$lineupname =~ s/.*name='([^']*).*/$1/;
				$lineuptype = $line;
				$lineuptype =~ s/.*type='([^']*).*/$1/;
				$lineupdevice = $line;
				$lineupdevice =~ s/.*device='([^']*).*/$1/;
				if ($lineupdevice eq $line) {
					$lineupdevice = "";
				}
				$lineupcode = $line;
				$lineupcode =~ s/.*postalCode='([^']*).*/$1/;

				if ($lineuptype =~ /Cable/) {
					$lineuptype = "Cable";
				}

				if ($lineuptype =~ /LocalBroadcast/) {
					$lineuptype = "Air";		
				}

				if ($lineuptype =~ /Satellite/) {
					$lineuptype = "DBS";
				}

				$lineupname = substr($lineupname,0,31);
				$lineupdevice = substr($lineupdevice,0,31);

				if (length($lineupname) > 0) {
					if ($lineupname ne $prevlineup) {
						if (length($prevlineup) > 0) {
							$lineupnumber++;
						}
					}
				}

				$prevlineup = $lineupname;

			}

			if ($line =~ /<map/) {
				$stationid = $line;
				$stationid =~ s/.*station='([^']*).*/$1/;
				$channel = $line;
				$channel =~ s/.*channel='([^']*).*/$1/;

				# Tack it onto our array record

				
				$program_displaynumber = $channel;
				if ($do_channelmap) {
					($program_displaynumber,$program_channel) = &mapChannel($program_displaynumber,$program_channel);
				}

				$program_tuning = $program_displaynumber + (($iteration + $lineupnumber) * $multiplier);

				if ($stationarray{$stationid} ne "") {
					$stationarray{$stationid} .= "\|$program_displaynumber";
					$stationarray{$stationid} .= "\|$program_tuning";
				}

				($program_tmsid,$program_channel,$program_channelname,$program_affiliate,$original_tuning,$adjusted_tuning) = split(/\|/,$stationarray{$stationid});

				$channel_iconsrc = "";
				$channel_hidden = 0;

				$program_affiliate = filterfield($program_affiliate);
				$program_channel = filterfield($program_channel);
				$program_channelname = filterfield($program_channelname);
				$channel_iconsrc = filterfield($channel_iconsrc);

				$FieldNames = "";
				$FieldNames .= "tmsid, affiliate, ";
		       		$FieldNames .= "tuning, displaynumber, channel, ";
				$FieldNames .= "display, iconsrc, hidden, ";
				$FieldNames .= "postalcode, systemtype, lineupname, ";
				$FieldNames .= "lineupdevice";
	
				$FieldValues = $null;
				$FieldValues .= "$program_tmsid, '$program_affiliate',"; 
        			$FieldValues .= "$program_tuning, $program_displaynumber, '$program_channel', ";
				$FieldValues .= "'$program_channelname', '$channel_iconsrc', $channel_hidden, ";
				$FieldValues .= "'$lineupcode', '$lineuptype', '$lineupname', ";
				$FieldValues .= "'$lineupdevice'";


				if ($stationarray{$stationid} ne "") {
					if ($do_not_insert) {
						print CSVFILE2 $FieldValues;
						print CSVFILE2 "\n";
					}else{
						$Stmt = "INSERT INTO $db_table_channels ($FieldNames) VALUES ($FieldValues);";

#########
# DEBUG
#
#					print "$Stmt\n\n";
#
########
						if (sqlStmt($prgdb_handle,$Stmt)) {
							# Added
	    					}else{
	       						my $sql_error = &GetLastSQLError() . "\n(" . &GetLastSQLStmt() . ")";
							abend("Failed: $sql_error at record $rows");

						}
					}
				}else{
					# Null Map
				}


			}		
		} until ($original_line =~ /<\/lineups>/);

#	
#		close DEBUG;
##############

		if ($verbose) {
			writeDebug("$xml_file: Seeking Program Block");
		}

		#----------------------------------------
		# Now we need to build a list of program 
		# data.
		#----------------------------------------

		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;
		} until ($original_line =~ /<programs>/);

		writeDebug("$xml_file: Parsing Programs");

		
		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;

			if ($line =~ /<program id=/) {
				$programid = $line;
				$programid =~ s/.*id='([^']*).*/$1/;
				$subtitle = "";
				$description = "";
				$mpaaRating = "";
				$starRating = "";
				$title = "";
				$runTime = "";
				$year = "";
				$advisory = "";
				$showType = "";
				$syndicatedEpisodeNumber = "";
				$originalAirDate = "";
			}		
			if ($line =~ /<title>/) {
				$title = $line;
				$title =~ s/.*<title>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<subtitle>/) {
				$subtitle = $line;
				$subtitle =~ s/.*<subtitle>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<description>/) {
				$description = $line;
				$description =~ s/.*<description>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<showType>/) {
				$showType = $line;
				$showType =~ s/.*<showType>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<syndicatedEpisodeNumber>/) {
				$syndicatedEpisodeNumber = $line;
				$syndicatedEpisodeNumber =~ s/.*<syndicatedEpisodeNumber>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<originalAirDate>/) {
				$originalAirDate = $line;
				$originalAirDate =~ s/.*<originalAirDate>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<mpaaRating>/) {
				$mpaaRating = $line;
				$mpaaRating =~ s/.*<mpaaRating>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<starRating>/) {
				$starRating = $line;
				$starRating =~ s/.*<starRating>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<runTime>/) {
				$runTime = $line;
				$runTime =~ s/.*<runTime>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<year>/) {
				$year = $line;
				$year =~ s/.*<year>([^<]*)\W.*/$1/;
			}
			if ($line =~ /<advisory>/) {
				$advisory_entry = $line;
				$advisory_entry =~ s/.*<advisory>([^<]*)\W.*/$1/;
				if (length($advisory) > 0) {
					$advisory .= ",";
				}
				$advisory .= $advisory_entry;
			}
			if ($line =~ /<\/program>/) {
			
				#-------------------------------------------------------------------------------------
				# DataDirect offers some extra fields, we will just add them to the description field.
				#-------------------------------------------------------------------------------------

				if (length($showType) > 0) {
					$description = "$showType. $description";
				}

				my $temp_field = "";
				my $temp_flag = 0;

				if ($show_episode_number) {
					if (length($syndicatedEpisodeNumber) > 0) {
						$temp_field .= "Ep \#$syndicatedEpisodeNumber";
						$temp_flag = 1;
					}
				}

				if ($show_first_aired_date) {
					if (length($originalAirDate) > 0) {
						if ($temp_flag) {
							$temp_field .= " ";
						}
						$temp_field .= "First Aired: $originalAirDate";
						$temp_flag = 1;
					}
				}

				if ($temp_flag) {
					$temp_field = " ($temp_field)";
				}

				$description .= $temp_field;

				$programarray{$programid} = "$programid\|$title\|$subtitle\|$description\|$mpaaRating\|$starRating\|$runTime\|$year\|$advisory";
			}

		} until ($original_line =~ /<\/programs>/);


		if ($use_castcrew > 0) {
			if ($verbose) {
				writeDebug("$xml_file: Seeking Cast/Crew Block");
			}

			do {
				$line = readline LISTINGS;
				chomp($line);
				$original_line = $line;
			} until ($original_line =~ /<productionCrew>/);
	
			writeDebug("$xml_file: Parsing Cast/Crew",1);

			do {
				$line = readline LISTINGS;
				chomp($line);
				$original_line = $line;
	
				if ($line =~ /<crew program=/) {
					$programid = $line;
					$programid =~ s/.*program='([^']*).*/$1/;
					$role = "";
					$surname = "";
					$givenname = "";

				}

				if ($line =~ /<member>/) {
					$role = "";
					$surname = "";
					$givenname = "";
				}		
				if ($line =~ /<role>/) {
					$role = $line;
					$role =~ s/.*<role>([^<]*)\W.*/$1/;
				}
				if ($line =~ /<givenname>/) {
					$givenname = $line;
					$givenname =~ s/.*<givenname>([^<]*)\W.*/$1/;
				}
				if ($line =~ /<surname>/) {
					$surname = $line;
					$surname =~ s/.*<surname>([^<]*)\W.*/$1/;
				}

				if ($line =~ /<\/member>/) {
					$roleid = 0;
					if (uc $role eq 'ACTOR') {
						$roleid = 1;
					}
					if (uc $role eq 'GUEST STAR') {
						$roleid = 2;
					}
					if (uc $role eq 'HOST') {
						$roleid = 3;
					}
					if (uc $role eq 'DIRECTOR') {
						$roleid = 4;
					}
					if (uc $role eq 'PRODUCER') {
						$roleid = 5;
					}
					if (uc $role eq 'EXECUTIVE PRODUCER') {
						$roleid = 6;
					}
					if (uc $role eq 'WRITER') {
						$roleid = 7;
					}

					# Write Data

					$programid = filterfield($programid);
					$surname = filterfield($surname);
					$givenname = filterfield($givenname);
	
					$FieldNames = "";
					$FieldNames .= "tmsprogramid, role, ";
			       		$FieldNames .= "surname, givenname ";
	
					$FieldValues = $null;
					$FieldValues .= "'$programid', $roleid, "; 
					$FieldValues .= "'$surname', '$givenname'";

					if ($do_not_insert) {
						print CSVFILE3 $FieldValues;
						print CSVFILE3 "\n";
					}else{
						$Stmt = "INSERT INTO $db_table_castcrew ($FieldNames) VALUES ($FieldValues);";
				
						if (sqlStmt($prgdb_handle,$Stmt)) {
							$rows++;
							$dotctr++;
		    				}else{
	       						my $sql_error = &GetLastSQLError() . "\n(" . &GetLastSQLStmt() . ")";
							abend("Failed: $sql_error at record $rows");

						}
					}

					if ($dotctr == $dotinterval) {
						if ($verbose) {
							displayText(".",0,1);
						}
						$dotctr = 0;
					}

					

				}
			} until ($original_line =~ /<\/productionCrew>/);

			writeDebug("Done!");
			writeDebug("$xml_file: Added $rows records of cast/crew information");
		}


		if ($verbose) {
			writeDebug("$xml_file: Seeking Genre Block");
		}

		#----------------------------------------
		# Now we need to build a list of genre 
		# data.
		#----------------------------------------


		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;
		} until ($original_line =~ /<genres>/);

		writeDebug("$xml_file: Parsing Genre Data");

		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;

			if ($line =~ /<programGenre program=/) {
				$programid = $line;
				$programid =~ s/.*program='([^']*).*/$1/;
				$genre = "";
			}		
			if ($line =~ /<class>/) {
				$class = $line;
				$class =~ s/.*<class>([^<]*)\W.*/$1/;
				if (length($genre) > 0) {
					$genre .= "/";
				}
				$genre .= $class;
			}
			if ($line =~ /<\/programGenre>/) {
				$categoryarray{$programid} = "$genre";
			}	
		} until ($original_line =~ /<\/genres>/);

	close LISTINGS;


	$rows = 0;
	$dotctr = 0;

	if (open(LISTINGS, "<$xml_file")) {
		writeDebug("$xml_file: Second Pass...");
	}else{
		abend("Could not open $xml_file");
	}

		if ($verbose) {
			writeDebug("$xml_file: Seeking Schedule Block");
		}

		#----------------------------------------
		# Now we need to build a list of schedule 
		# data.
		#----------------------------------------

		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;
		} until ($original_line =~ /<schedules>/);

		writeDebug("$xml_file: Parsing Schedule",1);
		$endrec = 0;

		do {
			$line = readline LISTINGS;
			chomp($line);
			$original_line = $line;

			if ($line =~ /<schedule program=/) {
				$programid = "";
				$stationid = "";
				$starttime = "";
				$duration = "";
				$closeCaptioned = "";
				$tvRating = "";
				$repeat = "";
				$subtitled = "";
				$stereo = "";
				$hdtv = "";
				$part = "";
				$partnumber = "";
				$parttotal = "";
			
				$programid = $line;
				$programid =~ s/.*program='([^']*).*/$1/;
				$stationid = $line;
				$stationid =~ s/.*station='(\d*)[^']*.*/$1/;
				$starttime = $line;
				$starttime =~ s/.*time='([^']*).*/$1/;
				$duration = $line;
				$duration =~ s/.*duration='([^']*).*/$1/;
				$repeat = $line;
				$repeat =~ s/.*repeat='([^']*).*/$1/;
				if ($repeat eq $line) {
					$repeat = "";
				}
				$tvRating = $line;
				$tvRating =~ s/.*tvRating='([^']*).*/$1/;
				if ($tvRating eq $line) {
					$tvRating = "";
				}
				$stereo = $line;
				$stereo =~ s/.*stereo='([^']*).*/$1/;
				if ($stereo eq $line) {
					$stereo = "";
				}
				$hdtv = $line;
				$hdtv =~ s/.*hdtv='([^']*).*/$1/;
				if ($hdtv eq $line) {
					$hdtv = "";
				}
				$subtitled = $line;
				$subtitled =~ s/.*subtitled='([^']*).*/$1/;
				if ($subtitled eq $line) {
					$subtitled = "";
				}
				$closeCaptioned = $line;
				$closeCaptioned =~ s/.*closeCaptioned='([^']*).*/$1/;
				if ($closeCaptioned eq $line) {
					$closeCaptioned = "";
				}
				if ($line =~ /\/>/) {
					$endrec = 1;
				}else{
					$endrec = 0;
				}
			}		
	
			if ($line =~ /<part number/) {
				$partnumber = $line;
				$partnumber =~ s/.*number='([^']*).*/$1/;
				$parttotal = $line;
				$parttotal =~ s/.*total='([^']*).*/$1/;
				$part = "Part $partnumber of $parttotal";
			}
			
			if ($line =~ /<\/schedule>/) {
				$endrec = 1;
			}		
			
			
			if ($endrec) {

				#----------------------------------------
				# Build Record and Normalize Data
				#----------------------------------------

				($program_tmsprgid,$program_title,$program_subtitle,$program_desc,$program_mpaarating,$program_starrating,$program_runtime,$program_movieyear,$program_advisories) = split(/\|/,$programarray{$programid});
				($program_tmsid,$program_channel,$program_channelname,$program_affiliate,$program_displaynumber,$program_tuning) = split(/\|/,$stationarray{$stationid});

				$program_category = $categoryarray{$programid};

				#----------------------------------------
				# convert $time to timestring and then to
				# local and then to a local timestring
				#----------------------------------------

				$timeGMT = substr($starttime,0,4) . substr($starttime,5,2) . substr($starttime,8,2) . substr($starttime,11,2) . substr($starttime,14,2) . substr($starttime,17,2);
				$eventtime = as_epoch_seconds($timeGMT);
				$hour = substr($duration,2,2);
				$minutes = substr($duration,5,2);
				$program_length = ($hour * 60) + $minutes;
				$starttime = timegm(localtime($eventtime));
		
				$stoptime = $starttime + ($program_length * 60);
				$program_start = as_time_string($starttime);
				$program_stop = as_time_string($stoptime);

				# Adjust Fields

				if ($repeat eq 'true') {
					$program_repeat = 1;
				}else{
					$program_repeat = 0;
				}

				if ($stereo eq 'true') {
					$program_audio = 1;
				}else{
					$program_audio = 0;
				}

				if ($closeCaptioned eq 'true') {
					$program_captions = $closeCaptioned;
				}else{
					$program_captions = "";
				}
			
				if ($subtitled eq 'true') {
					$program_issubtitled = 1;	
				}else{
					$program_issubtitled = 0;	
				}		
			

				if (substr($program_tmsprgid,0,2) eq 'MV') {
						$program_ismovie = 1;
				}else{
						$program_ismovie = 0;
				}

				if ($tvRating =~ /-/) {
					$program_vchiprating = substr($tvRating,3);
				}else{
					$program_vchiprating = substr($tvRating,2);
				}
				$program_episodenum = $part;

				if (length($program_starrating) > 0) {	
					my $starsize = length($program_starrating);
					if (substr($program_starrating,$starsize-1,1) eq "+") {
						$starsize--;
						if ($starsize < 0) {
							$starsize = 0;
						}
						$starsize = $starsize + .5;
					}
					$program_starrating = "$starsize/4";
				}

				if ($do_titlemap) {
					$program_title = &mapTitle($program_title);
				}

				if ($do_channelmap) {
					($program_tuning,$program_channel) = &mapChannel($program_tuning,$program_channel);
				}
	

#				$program_tuning = $program_tuning + ($iteration * $multiplier);

	
				$Stmt = "";
				$dataok = 1;
	
				$program_title = filterfield(convertfromhtml($program_title));
				$program_desc = filterfield(convertfromhtml($program_desc));
				$program_subtitle = filterfield(convertfromhtml($program_subtitle));	
				$program_category = filterfield($program_category);
				$program_advisories = filterfield($program_advisories);
				$program_tmsprgid = filterfield($program_tmsprgid);
				$program_vchiprating = filterfield($program_vchiprating);
				$program_episodenum = filterfield($program_episodenum);

				($Y,$M,$D,$h,$m,$s) = unpack 'A4 A2 A2 A2 A2 A2', $program_start;
				$program_start = "$Y-$M-$D $h:$m:$s";

				($Y,$M,$D,$h,$m,$s) = unpack 'A4 A2 A2 A2 A2 A2', $program_stop;
				$program_stop = "$Y-$M-$D $h:$m:$s";


				$FieldNames = $null;
				$FieldNames .= "tmsprogramid, tmsid, ";
		       		$FieldNames .= "starttime, endtime, tuning, ";
				$FieldNames .= "channel, title, subtitle, ";
				$FieldNames .= "description, category, stereo, ";
				$FieldNames .= "captions, episodenum, vchiprating, ";
				$FieldNames .= "mpaarating, starrating, movieyear, ";
				$FieldNames .= "repeat, movie, subtitled, ";
				$FieldNames .= "advisories";

				$FieldValues = $null;
				$FieldValues .= "'$program_tmsprgid', $program_tmsid, ";
			       	$FieldValues .= "'$program_start', '$program_stop', $program_tuning, ";
				$FieldValues .= "'$program_channel', '$program_title', '$program_subtitle', ";
				$FieldValues .= "'$program_desc', '$program_category', $program_audio, ";
				$FieldValues .= "'$program_captions', '$program_episodenum', '$program_vchiprating', ";
				$FieldValues .= "'$program_mpaarating', '$program_starrating', '$program_movieyear', ";
				$FieldValues .= "$program_repeat, $program_ismovie, $program_issubtitled, ";
				$FieldValues .= "'$program_advisories'";

				if ($dataok) {
					if ($do_not_insert) {
						writeDebug("SQL Insert Disabled, Writing to CSV:");
				
						print CSVFILE $FieldValues;
						print CSVFILE "\n";
	
					}else{
						$Stmt = "INSERT INTO $db_table_tvlistings ($FieldNames) VALUES ($FieldValues);";

#########
# DEBUG
#
#						print DEBUG "$rows:$Stmt\n";
#
########
						if (sqlStmt($prgdb_handle,$Stmt)) {
							$rows++;
							$dotctr++;
					    	}else{
	       						my $sql_error = &GetLastSQLError() . "\n(" . &GetLastSQLStmt() . ")";
							abend("Failed: $sql_error at record $rows");

						}
					}
				}

				if ($dotctr == $dotinterval) {
					if ($verbose) {
						displayText(".",0,1);
					}
					$dotctr = 0;
				}
	
				if ($maxrows) {
					if ($rows > $maxrows) {
						close LISTINGS;
						if ($do_not_insert) {
							close CSVFILE;
						}
						abend("Done! Max Rows Reached ($maxrows)");
					}
				}

				$endrec = 0;
			}

		} until ($original_line =~ /<\/schedules>/);

	close LISTINGS;
	writeDebug("Done!");
	writeDebug("$xml_file: Processing Complete!");
	$iteration++;
}


if ($do_not_insert) {
	close CSVFILE;
	close CSVFILE2;
	$rows = 0;
}else{
	writeDebug("$rows rows were added");
}

$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Terminating Database Connection from $DATASOURCE{DSN} ($prgdb_handle)");
endDSN("",$prgdb_handle);

writeDebug("Job finished at $now ($runtime seconds)");

if ($rows) {
	writeDebug("Dispatching rg_refresh");
	require 'rg_refresh.pl';		# Load RTV refresh functions	
	identifyLoadedModules('rg_refresh.pl');	# ID	
	refreshRTV($verbose);			# Refresh
	writeDebug("Returned from rg_refresh");
	$retcode = 1;
}

&ShowHTTPFooter;

writeDebug("********************************************************");

exit($retcode);

#----------------------------------------------------------------------------
sub mapChannel {
	#
	# Remap Channel (Tuning,ChannelID)
	# 
	# Returns (Tuning,ChannelID)
	#
	# ------------------------------------------------------------------------------

	my $tuning = shift;
	my $channelid = shift;

	if ($cmap_ctr < 1) {
		return ($tuning,$channelid);
	}

	my $before = "";
	my $after = "";
	my $ctr = 0;

	do {
		$ctr++;
    		($before,$after) = split('=', $channelmap[$ctr], 2);
		
		if ($before eq "$channelid,$tuning") {
			($channelid,$tuning) = split(',', $after, 2);
		}

	} while ($ctr <= $cmap_ctr);

	return ($tuning,$channelid);
}

#----------------------------------------------------------------------------
sub mapTitle {
	#
	# Remap Title (Title)
	# 
	# Returns (Title)
	#
	# ------------------------------------------------------------------------------

	my $title = shift;

	if ($tmap_ctr < 1) {
		return $title;
	}

	my $before = "";
	my $after = "";
	my $ctr = 0;

	do {
		$ctr++;
    		($before,$after) = split('=', $titlemap[$ctr], 2);
		
		if ($before eq $title) {
			$title = $after;
		}

	} while ($ctr <= $tmap_ctr);

	return $title;
}
