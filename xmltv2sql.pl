#!/usr/bin/perl
#
# Personal ReplayGuide SQL Converter
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
#  $Id: xmltv2sql.pl,v 1.9 2003/08/10 19:12:44 pvanbaren Exp $
#
# Requirements: 
#	XMLTV (using tv_grab_na)
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

use POSIX qw( strftime getcwd );
use English;
use Time::Local;
require LWP::Simple;
require LWP::UserAgent;
require HTTP::Request;
require HTTP::Headers;

my $_version = "Personal ReplayGuide|XMLTV XML to SQL Converter|1|2|84|Lee Thompson,Philip Van Baren,Kanji T. Bates";

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

$retcode = 0;
$debug = 0;				# Debug Messages
$multiplier = 1000;			# Default Multiplier
$dotinterval = 500;			# Interval for the "." 
$maxrows = 0;				# Maximum Number of rows to INSERT
$cnf_xmlfile = "./na.xml";		# XMLTV file
$cnf_channelmap = "";
$cnf_titlemap = "";
$verbose = 1;				# Chatty
$systemtype = "";			
$lineupname = "";
$postalcode = "";
$lineupdevice = "";

$configfile = "xmltv2sql.conf";		# This is optional
$configstatus = getConfig($configfile);	# Read Configuration

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
	writeDebug("Attempt to Connect Failed: " . &GetLastSQLError()); 
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

writeDebug("Depending on the speed of the machine and the number of days worth of listings this may take approximately 20 minutes.");


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
	$FieldNames .= "description, category, audio, ";
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


}


$iteration = 0;


for ( split /,/, $cnf_xmlfile ) {
	/,/;
	$xml_file = $_;

	#-------------------------------------------------------------------
	# Open File
	#-------------------------------------------------------------------

	if (open(LISTINGS, "<$xml_file")) {
		writeDebug("$iteration: Reading XMLTV Feed ($xml_file)");

	}else{
		abend("Could not open $xml_file");
	}

	#-------------------------------------------------------------------
	# Convert XML to SQL
	#-------------------------------------------------------------------

	writeDebug("$iteration: $xml_file Parsing Data...",1);

	while(<LISTINGS>) {

		#-----------------------------------------------------------
		# Parse XML
		#-----------------------------------------------------------

		$line = $_;
		chomp($line);
		$original_line = $line;

		#-----------------------------------------------------------
		# CHANNELS
		#-----------------------------------------------------------

		if ( /<channel\s/ ) {
			$stationid = $line;
			$stationid =~ s/.*id="([^"]*).*/$1/;
			$channel_display = "";
			$channel_iconsrc = "";
			$channel_hidden = 0;
			$channel_affiliate = "";
			$channel_tmsid = 0;
			$channel_type = "";
			$channel_tuning = 0;
			$channel_text = "";
			$tmp_channel_display = "";
		}
		if ( /<channel-id system=\"TMSID\" id=\"(\d+)"/ ) {
			$channel_tmsid = $1;
		}

		if ( /<display-name/ ) {	
			$tmp_channel_display = $line;
			$tmp_channel_display =~ s/.*<display-name>([^<]*)\W.*/$1/;
			if ($tmp_channel_display =~ /(\d+) (\S+)/) {
				$channel_display = $tmp_channel_display;
				$channel_tuning = $1;
				$channel_text = $2;
			}
		}

		if ( /<icon/ ) {
			$channel_iconsrc = $line;
			$channel_iconsrc =~ s/.*src="([^"]*)\W.*/$1/;
		}

        	if ( /<\/channel/ ) {

			if ($do_channelmap) {
				($channel_tuning,$channel_text) = &mapChannel($channel_tuning,$channel_text);
			}
			
			$channel_displayname = $channel_tuning;
			$channel_tuning = $channel_tuning + ($iteration * $multiplier);
			
			$channel_affiliate = filterfield($channel_affiliate);
			$channel_text = filterfield($channel_text);
			$channel_display = filterfield($channel_display);
			$channel_iconsrc = filterfield($channel_iconsrc);

			$Stmt = "";
		

			$FieldNames = "";
			$FieldNames .= "tmsid, affiliate, ";
	       		$FieldNames .= "tuning, displaynumber, channel, ";
			$FieldNames .= "display, iconsrc, hidden, ";
			$FieldNames .= "postalcode, systemtype, lineupname, ";
			$FieldNames .= "lineupdevice";
	
			$FieldValues = "";
			$FieldValues .= "$channel_tmsid, '$channel_affiliate',"; 
        		$FieldValues .= "$channel_tuning, $channel_displayname, '$channel_text', ";
			$FieldValues .= "'$channel_display', '$channel_iconsrc', $channel_hidden, ";
			$FieldValues .= "'$postalcode', '$systemtype', '$lineupname', ";
			$FieldValues .= "'$lineupdevice'";

			if ($do_not_insert) {
				print CSVFILE2 $FieldValues;
				print CSVFILE2 "\n";
			}else{
				$Stmt = "INSERT INTO $db_table_channels ($FieldNames) VALUES ($FieldValues);";
	
				if (sqlStmt($prgdb_handle,$Stmt)) {
						# Added
	    				}else{
	       					my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
						abend("Failed: $sql_error");

				}
			}



			$stationarray{$stationid} = "$stationid\|$channel_text\|$channel_display\|$channel_affiliate\|$channel_tuning";
			
		}


		#-----------------------------------------------------------
		# PROGRAMS
		#-----------------------------------------------------------

		if ( /<programme/ ) {
			$program_start = $line;
			$program_start =~ s/.*start="(\d*)[^"]*.*/$1/;
			$program_stop = $line;
			$program_stop =~ s/.*stop="(\d*)[^"]*.*/$1/;
			$stationid = $line;
			$stationid =~ s/.*channel="([^"]*).*/$1/;

			$program_title = "";
			$program_audio = 0;
			$program_subtitle = "";
			$program_category = "";
			$program_desc = "";

			$program_captions = "";
			$program_episodenum = "";
			$program_vchiprating = "";
			$program_mpaarating = "";
			$program_starrating = "";
			$program_movieyear = "";
			$program_repeat = 0;
			$program_ismovie = 0;
			$program_issubtitled = 0;
			$program_advisories = "";

			$program_ratingsystem = "";
		}

		if ( /<subtitles/ ) {
			$program_captions = $line;
			$program_captions =~ s/.*type="([^"]*).*/$1/;
	
		}

		if ( /<episode-num/ ) {
			$program_episodenum = $line;
			if ($program_episodenum =~ "onscreen") {
				$program_episodenum =~ s/.*onscreen">([^<]*)\W.*/$1/;
			}
			if ($program_episodenum =~ "xmltv_ns") {
				$program_episodenum =~ s/.*xmltv_ns">([^<]*)\W.*/$1/;
				(my $series, my $episode, my $parts) = split(/\./,$program_episodenum);
				(my $part, my $total) = split(/\//,trimstring($parts));
				if ($part > 0) {
					if ($total > 0) {
						$program_episodenum = "Part $part of $total";
					}else{
						$program_episodenum = "Part $part";
					}
				}else{
					$program_episodenum = "";
				}
			}
			if ($program_episodenum eq $line) {
				$program_episodenum = "";
			}
		}

		if ( /<rating/ ) {
			$program_ratingsystem = $line;
			$program_ratingsystem =~ s/.*system="([^"]*).*/$1/;
			if ($program_ratingsystem eq $line) {
				$program_ratingsystem = "";
			}
		}

		if ( /<star-rating/ ) {
			$program_ratingsystem = "STAR";
		}

		if ( /<value/ ) {
			if ($program_ratingsystem eq "VCHIP") {
				$program_vchiprating = $line;
				$program_vchiprating =~ s/.*<value>([^<]*)\W.*/$1/;
				if ($program_vchiprating eq $line) {
					$program_vchiprating = "";
				}

			}
			if ($program_ratingsystem eq "MPAA") {
				$program_mpaarating = $line;
				$program_mpaarating =~ s/.*<value>([^<]*)\W.*/$1/;
				if ($program_mpaarating eq $line) {
					$program_mpaarating = "";
				}
			}		
			if ($program_ratingsystem eq "STAR") {
				$program_starrating = $line;
				$program_starrating =~ s/.*<value>([^<]*)\W.*/$1/;
				if ($program_starrating eq $line) {
					$program_starrating = "";
				}
			}
		}

		if ( /<date>/ ) {
			$program_movieyear = $line;
			$program_movieyear =~ s/.*<date>([^<]*)\W.*/$1/;
			if ($program_movieyear eq $line) {
				$program_movieyear = "";
			}
		}

		if ( /<title>/ ) {
			$program_title = $line;
			$program_title =~ s/.*<title>([^<]*)\W.*/$1/;
			if ($program_title eq $line) {
				$program_title = "";
			}
		}

		if ( /<desc>/ ) {
			$program_desc = $line;
			$program_desc =~ s/.*<desc>([^<]*)\W.*/$1/;
			if ($program_desc eq $line) {
				$program_desc = "";
			}
		}

		if ( /<sub-title>/ ) {
			$program_subtitle = $line;
			$program_subtitle =~ s/.*<sub-title>([^<]*)\W.*/$1/;
			if ($program_subtitle eq $line) {
				$program_subtitle = "";
			}
		}

		if ( /<category>/ ) {
			if (length($program_category) > 0) {
				$old_category = $program_category;
			}

			$program_category = $line;
			$program_category =~ s/.*<category>([^<]*)\W.*/$1/;

			if (length($old_category) > 0) {
				$program_category = "$old_category/$program_category";
				$old_category = "";
			}
		}

		if ( /<stereo>/ ) {
			$program_audio = 1;
		}
	
		if ( /<previously-shown/ ) {
			$program_repeat = 1;
		}
	
	        if ( /<\/programme/ ) {
			($program_tmsid,$program_channel,$program_channelname,$program_affiliate,$program_tuning) = split(/\|/,$stationarray{$stationid});

			if ($do_titlemap) {
				$program_title = &mapTitle($program_title);
			}

			if ($do_channelmap) {
				($program_tuning,$program_channel) = &mapChannel($program_tuning,$program_channel);
			}
	
			$Stmt = "";
		
			$dataok = 1;


			($Y,$M,$D,$h,$m,$s) = unpack 'A4 A2 A2 A2 A2 A2', $program_start;
			$program_start = "$Y-$M-$D $h:$m:$s";
			$Y = int $Y;
		
			if ($Y < 1) {
				$dataok = 0;
			}
		
			#-----------------------------------------------------------
			# XMLTV is braindead if a program runs past midnight it
			# omits the endtime entirely unless you use their sorter.
			#-----------------------------------------------------------

			($Y,$M,$D,$h,$m,$s) = unpack 'A4 A2 A2 A2 A2 A2', $program_stop;
			$program_stop = "$Y-$M-$D $h:$m:$s";

			if ($Y < 1) {

			#-----------------------------------------------------------
			# We'll mark it by making the start and stop times the same and
			# Do another pass
			#-----------------------------------------------------------

				if ($dataok) {
					$program_stop = $program_start;
					$emptystop++;
				}else{
					$dataok = 0;
				}
			}


			$program_title = filterfield($program_title);
			$program_desc = filterfield($program_desc);
			$program_subtitle = filterfield($program_subtitle);	
			$program_category = filterfield($program_category);
			$program_audio = filterfield($program_audio);
			$program_vchiprating = filterfield($program_vchiprating);
			$program_episodenum = filterfield($program_episodenum);

			if (int $program_movieyear > 0) {
				$program_ismovie = 1;
			}else{
				$program_ismovie = 0;
			}

			#-----------------------------------------------------------
			# Not Available for XMLTV
			#-----------------------------------------------------------

			$program_tmsid = 0;
			$program_advisories = "";
			$program_tmsprgid = "";

			$FieldNames = "";
			$FieldNames .= "tmsprogramid, tmsid, ";
	       		$FieldNames .= "starttime, endtime, tuning, ";
			$FieldNames .= "channel, title, subtitle, ";
			$FieldNames .= "description, category, stereo, ";
			$FieldNames .= "captions, episodenum, vchiprating, ";
			$FieldNames .= "mpaarating, starrating, movieyear, ";
			$FieldNames .= "repeat, movie, subtitled, ";
			$FieldNames .= "advisories";

			$FieldValues = "";
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

					if ($debug) { 
						writeDebug("$Stmt"); 
					}

					if (sqlStmt($prgdb_handle,$Stmt)) {
						$rows++;
						$dotctr++;
					 }else{
	       					my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
						abend("Failed: $sql_error");

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

		}

	}
	close LISTINGS;
	displayText();
	writeDebug("Initial processing XMLTV data completed.");
	$iteration++;
}


if ($do_not_insert) {
	close CSVFILE;
	close CSVFILE2;
	abend("Done! Do not insert set to $do_not_insert");
}else{
	
}

writeDebug("$rows rows were added");


#-----------------------------------------------------------
# Do Another Pass if Needed
#-----------------------------------------------------------

if ($emptystop) {

	writeDebug("Fixing $emptystop occurances of missing end points");

	writeDebug("Locating Records",1);
	$dotctr = 0;

	#-----------------------------------------------------------
	# First we need to locate them
	#-----------------------------------------------------------

	$Stmt = "SELECT * FROM $db_table_tvlistings WHERE starttime = endtime ORDER BY tuning, channel, starttime;";
	$ctr = 1;

	my $lookup_handle = &StartDSN(1);
	$sth = sqlStmt($lookup_handle,$Stmt);
	if ( $sth ) {

		while ( $row = $sth->fetchrow_hashref ) {
			$programid = $row->{'programid'};
			$tuning = $row->{'tuning'};
			$channel = $row->{'channel'};
			$starttime = $row->{'starttime'};

			$arrayprogramid[$ctr] = $programid;
			$arraytuning[$ctr] = $tuning;
			$arraychannel[$ctr] = $channel;
			$arraystarttime[$ctr] = $starttime;
			$arrayendtime[$ctr] = $starttime;

			$ctr++;
			$dotctr++;

			if ($dotctr == $dotinterval) {
				if ($verbose) { 
					displayText(".",0,1);
				}
				$dotctr = 0;
			}

		}
	}else{
			displayText();
			writeDebug("Error at $ctr / $emptystop - (Phase 1)");
			my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
			abend("Failed: $sql_error");

	}
	endDSN($sth,$lookup_handle);
	undef $lookup_handle;


	$maxctr = $ctr;	
	$ctr = 1;
	$dotctr = 0;

	displayText();
	writeDebug("Collecting Endpoints",1);

	#-----------------------------------------------------------
	# Now we need the end times
	#-----------------------------------------------------------

	my $query_handle = &StartDSN;

	do {
		$programid = $arrayprogramid[$ctr];
		$tuning = $arraytuning[$ctr];
		$channel = $arraychannel[$ctr];
		$starttime = $arraystarttime[$ctr];
		$endtime = $arrayendtime[$ctr];
		$endsearch = timestringtosql(as_time_string(as_epoch_seconds(sqltotimestring($starttime)) + 86400));

		$Stmt = "";
		$Stmt = "SELECT * FROM $db_table_tvlistings WHERE (((programid <> '$programid' AND starttime > '$starttime') AND tuning = $tuning) AND channel = '$channel') ORDER BY tuning, channel, starttime;";

		if ($db_driver eq "mysql") {
			$Stmt = "SELECT * FROM $db_table_tvlistings WHERE (((programid <> '$programid' AND starttime > '$starttime') AND tuning = $tuning) AND channel = '$channel') ORDER BY tuning, channel, starttime LIMIT 1;";

		}

		if ($db_driver eq "SQLite") {
			$Stmt = "SELECT * FROM $db_table_tvlistings WHERE (((programid <> '$programid' AND starttime > '$starttime') AND tuning = $tuning) AND channel = '$channel') ORDER BY tuning, channel, starttime LIMIT 1;";

		}

		if ($db_driver eq "ODBC") {
			$Stmt = "SELECT TOP 1 * FROM $db_table_tvlistings WHERE (((programid <> '$programid' AND starttime > '$starttime') AND tuning = $tuning) AND channel = '$channel') ORDER BY tuning, channel, starttime;";
		}

		$sth = sqlStmt($query_handle,$Stmt);
		if ( ! $sth ) {
				displayText();
			        writeDebug("Error at $ctr / $maxctr - (Phase 2)");
				my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
				abend("Failed: $sql_error");

		}

		$row = $sth->fetchrow_hashref;		# this should be the one after it
		
		$endtime = $row->{'starttime'};

		$arrayendtime[$ctr] = $endtime;
		
		$ctr++;		
		$dotctr++;

		if ($dotctr == $dotinterval) {
			if ($verbose) {
				displayText(".",0,1);
			}
			$dotctr = 0;
		}


	} while ($ctr < $maxctr);
	endDSN($sth,$query_handle);
	undef $query_handle;

	$ctr = 1;

	$dotctr = 0;

	displayText();
	writeDebug("Updating Records",1);

	#-----------------------------------------------------------
	# now we update the records
	#-----------------------------------------------------------

	my $update_handle = &StartDSN;
	
	do {
		$programid = $arrayprogramid[$ctr];
		$tuning = $arraytuning[$ctr];
		$starttime = $arraystarttime[$ctr];
		$endtime = $arrayendtime[$ctr];

		$Stmt = "UPDATE $db_table_tvlistings SET endtime = '$endtime' WHERE programid = '$programid';";
		if (sqlStmt($update_handle,$Stmt)) {
				# Corrected
		}else{
				displayText();
			        writeDebug("Error at $ctr / $maxctr - (Phase 3)");
				my $sql_error = &GetLastSQLError() . " (" . &GetLastSQLStmt() . ")";
				abend("Failed: $sql_error");

		}
		
		$ctr++;		
		$dotctr++;

		if ($dotctr == $dotinterval) {
			if ($verbose) {
				displayText(".",0,1);
			}
			$dotctr = 0;
		}


	} while ($ctr < $maxctr);
	endDSN("",$update_handle);

	$ctr--;

	displayText();
	writeDebug("$ctr records corrected");
}


$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

writeDebug("Terminating Database Connection from $DATASOURCE{DSN} ($prgdb_handle)");
endDSN($sth,$prgdb_handle);

writeDebug("Job finished at $now ($runtime seconds)");


if ($rows) {
	writeDebug("Dispatching rg_refresh");
	require 'rg_refresh.pl';		# Load RTV refresh functions		
	identifyLoadedModules('rg_refresh.pl');	# ID	
	&refreshRTV($verbose);			# Refresh (0 is silent,
						#          1 is verbose
						#	   2 is debug)
	writeDebug("Returned from rg_refresh");
	$retcode = 1;
}

&ShowHTTPFooter;

writeDebug("********************************************************");

exit($retcode);

#----------------------------------------------------------------------------
sub mapChannel($$) {
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
sub mapTitle($) {
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
