#!/usr/bin/perl
#
# ReplayTV Recording Scheduler
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
#  $Id: schedule.pl,v 1.6 2003/07/29 12:46:17 pvanbaren Exp $
#
# NOTE: This will break in 2038.
#
#------------------------------------------------------------------------------------
#
# This version of schedule.pl is branched to be part of Personal ReplayGuide, if you
# want an independant version it is available as "ind_schedule.pl" in this package.
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
#-------------------------------------------------------------------------------------

require HTTP::Request;
require HTTP::Headers;
require LWP::UserAgent;
use Time::Local;
use CGI qw(:standard);
use POSIX qw( strftime getcwd );

my $_version = "Personal ReplayGuide|ReplayTV Recording Scheduler|1|1|64|Lee Thompson";

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

require 'rg_common.pl';
require 'rg_config.pl';	
require 'rg_replay.pl';

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


#-------------------------------------------------------------------------------------
# Initialize and Process Options
#-------------------------------------------------------------------------------------

$scriptname = $script_pathname;
$configfile = "schedule.conf";
$createconfig = 0;
$configstatus = getConfig("replayguide");	
$configstatus = getConfig($configfile);	

#-------------------------------------------------------------------------------------

(my $parent,my $desc,my $major,my $minor,my $build,my $authors) = parseModuleData($prg_module{$module_name});

$program_title = $parent;
$program_module = $desc;
$program_author = buildMultiWordList($authors);
$program_version = "$major.$minor";
$program_build = $build;

$debug_supress_slot_request = 0;
$debug_supress_show_request = 0;		# Flip to 1 if you don't want it to really request the recording!

CGI::import_names('input'); 

$RemoteAddress = $ENV{'REMOTE_ADDR'};

$started = time;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );

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

writeDebug("Job started at $now");

&GetWebData;

&InitializeDisplay;

if ($showbuttonicons < 1) {
	$icon_confirm = "";
	$icon_schedule = "";
	$icon_done = "";
}


#------------------------------------------------------------------------
# Set up Variables

$null = "";

$DWORD = 8;
$WORD = 4;
$BYTE = 2;

$html_state = 0;
$slot_response_size = 224;

$do_slot_request = 1;
$do_slot_confirm = 1;
$do_record_request = 1;

if ($debug) {
	writeDebug("Debug Messages are ON");
}

if ($debug_supress_slot_request) {
	writeDebug("Slot requests will NOT be made");
}

if ($debug_supress_show_request) {
	writeDebug("Show requests will NOT be made");
}

if ($interactive) {
	writeDebug("Interactive Mode");	
}

if (hasAccess($RemoteAddress) > 0) {
	# Access Granted
}else{
	abend("Access Denied");
}

#-------------------------------------------------------------------------------------
# Set Up Headers



#-------------------------------------------------------------------------------------
# Parse Input Fields and Build Slot Data

# depending on state, either prsent a form or process form input	

$url_parms = "";
$htmlstate = getParameter("state");
if ($htmlstate eq $null) {
	$htmlstate = "start";
}

if ($htmlstate eq "start") {	
	$do_slot_request = 0;
	$do_slot_confirm = 0;
	$do_record_request = 0;
	&FormStart;
}

if ($htmlstate eq "manual") {	
	if ($debug) {
		writeDebug("ManualRecording");
	}
	$do_slot_request = 0;
	$do_slot_confirm = 0;
	$do_record_request = 0;
	&FormManual;
}

if ($htmlstate eq "regular") {	
	if ($debug) {
		writeDebug("RegularRecording");
	}
	$do_slot_request = 0;
	$do_slot_confirm = 0;
	$do_record_request = 0;
	&FormRegular;
}
	
if ($htmlstate eq "slotrequest") {
	if ($debug) {
		writeDebug("SlotRequest");
	}
	$do_slot_request = 1;
	$do_slot_confirm = 1;
	$do_record_request = 0;
}

if ($htmlstate eq "recordshow") {
	if ($debug) {
		writeDebug("RecordShow");
	}
	$do_slot_request = 0;
	$do_slot_confirm = 0;
	$do_record_request = 1;
	$inp_selectedslot = $input::SELECTEDSLOT;
	$inp_quality = $input::QUALITY;
	$inp_return_url = $input::RETURNURL;		# Special Applications
	$inp_return_text = $input::RETURNTEXT;		# Special Applications
	$ReplayTV = $input::REPLAYTV;
}

if ($debug) {
	if (($do_slot_request) || ($do_slot_confirm) || ($do_record_request)) {
		&DisplayOptions;
	}
}

#-------------------------------------------------------------------------------------
# If HTML Mode, check to see if we have a CURRENTSLOT already, if so skip this section

#-------------------------------------------------------------------------------------
# Make the Slot Request

if ($do_slot_request) {
	if ($inp_manual) {
		if ($debug) {
			writeDebug("Getting ManualSlotRequest");
		}

		if ($debug) {
			writeDebug("buildSlotData: $inp_year,$inp_month,$inp_day,$inp_hour,$inp_minute,$inp_length,$inp_channel,$inp_quality,$inp_guaranteed,$inp_recurring,$inp_daysofweek,$inp_keep,$inp_isgmt,$inp_inputsource,$inp_tuning");
		}

		$SlotData = buildSlotData($inp_year,$inp_month,$inp_day,$inp_hour,$inp_minute,$inp_length,$inp_channel,$inp_quality,$inp_guaranteed,$inp_recurring,$inp_daysofweek,$inp_keep,$inp_isgmt,$inp_inputsource,$inp_tuning);

		if ($debug) {
			writeDebug("buildSlotData Returned: $SlotData");
			writeDebug("getManualSlotRequest: $ReplayTV,$SlotData");
		}

		$SlotResponse = getManualSlotRequest($ReplayTV,$SlotData);

		if ($debug) {
			writeDebug("getManualSlotRequest Returned: $SlotResponse");
		}

	}else{
		if ($debug) {
			writeDebug("Building Program Structure");
		}

		if ($debug) {
			writeDebug("buildProgram: $inp_year,$inp_month,$inp_day,$inp_hour,$inp_minute,$inp_title,$inp_length");
		}

		$Program = buildProgram($inp_year,$inp_month,$inp_day,$inp_hour,$inp_minute,$inp_title,$inp_length);

		if ($debug) {
			writeDebug("buildProgram Returned: $Program");
			writeDebug("Building Record Request Structure");
			writeDebug("buildRecordRequest: $inp_year,$inp_month,$inp_day,$inp_hour,$inp_minute,$inp_length,$inp_tuning,$inp_quality,$inp_guaranteed,$inp_recurring,$inp_daysofweek,$inp_keep,$inp_firstrun,$inp_isgmt,$inp_category,$inp_postpad,$inp_prepad");
		}

		$RecordRequest = buildRecordRequest($inp_year,$inp_month,$inp_day,$inp_hour,$inp_minute,$inp_length,$inp_tuning,$inp_quality,$inp_guaranteed,$inp_recurring,$inp_daysofweek,$inp_keep,$inp_firstrun,$inp_isgmt,$inp_category,$inp_postpad,$inp_prepad);

		if ($debug) {
			writeDebug("buildRecordRequest Returned: $RecordRequest");
			writeDebug("getSlotRequest: $ReplayTV,$Program,$RecordRequest");
		}

		$SlotResponse = getSlotRequest($ReplayTV,$Program,$RecordRequest);

		if ($debug) {
			writeDebug("getManualSlotRequest Returned: $SlotResponse");
		}
	}


	# Handle any errors

	if ($SlotResponse == -1) {
		displayText("Error contacting DVR at $ReplayTV.");
		writeDebug("Error contacting DVR at $ReplayTV.");
		$do_record_request = 0;
		$do_slot_request = 0;
		$do_slot_confirm = 0;
	}

	if ($SlotResponse == 0) {
		displayText("Slot not available on DVR at $ReplayTV.");
		writeDebug("Slot not available on DVR at $ReplayTV.");
		$do_record_request = 0;
		$do_slot_request = 0;
		$do_slot_confirm = 0;
	}

	if ($SlotResponse == 2) {
		displayText("Slot not requested to DVR at $ReplayTV.");
		writeDebug("Slot not requested to DVR at $ReplayTV.");
	}
}


#-------------------------------------------------------------------------------------
# Show Available Slots and either present a confirmation or selection 

#-------------------------------------------------------------------------------------

if ($do_slot_confirm) {
	$n_slots = int (length($SlotResponse) / $slot_response_size);
	$c_slot = 1;

	$SelectedSlot = 1;

	if ($n_slots == 1) {
		displayHeading("Confirm Selection:");
	}else{
		displayHeading("Select which program to schedule:\n");
	}

	$do_record_request = 0;
	$url_parms = "";
	addParameter("state","recordshow");
	print "<form method=POST action=$scriptdir/$schedulename$url_parms>\n";
	print "<input type=\"hidden\" value=\"$showpdaformat\" name=\"SHOWPDAFORMAT\">\n";
	print "<input type=\"hidden\" value=\"$ReplayTV\" name=\"REPLAYTV\">\n";
	print "<input type=\"hidden\" value=\"$inp_quality\" name=\"QUALITY\">\n";
	print "<input type=\"hidden\" value=\"$inp_return_text\" name=\"RETURNTEXT\">\n";
	print "<input type=\"hidden\" value=\"$inp_return_url\" name=\"RETURNURL\">\n";

	do {
		$CurrentSlot = substr($SlotResponse,($c_slot-1) * $slot_response_size,$slot_response_size);
		print "<font face=\"$font_menu\">";
		print "<input type=\"radio\" value=\"$CurrentSlot\" name=\"SELECTEDSLOT\">\n";
		if ($showpdaformat) {
			print "<font size=-1>";
		}
		print parseSlotData($CurrentSlot);
		if ($showpdaformat) {
			print "</font>";
		}
		print "</font><br>\n";
		$c_slot++;

	} while ($c_slot <= $n_slots);

	print "<p>";
	if (length($icon_confirm) > 0) {
		print "<input type=image src=\"$imagedir/$icon_confirm\" ALT=\"Confirm\">\n";
	}else{
		print "<input type=submit value=\"Confirm\" name=\"SUBMIT2\">\n";
	}
	print "</form><p>\n";

	if ($SelectedSlot > 0) {
		$CurrentSlot = substr($SlotResponse,($SelectedSlot-1) * $slot_response_size,$slot_response_size);
	}else{
		$CurrentSlot = "CANCEL";
	}
}else{
	# Already have the slot selected, make the record request
	$CurrentSlot = $inp_selectedslot;
}

#-------------------------------------------------------------------------------------
# Handle Cancelation
#-------------------------------------------------------------------------------------

if ($CurrentSlot eq "CANCEL") {
	writeDebug("Recording cancelled");
	$do_record_request = 0;
}else{
	if (($do_slot_request) || ($do_slot_confirm)) {
		if (length($CurrentSlot) != $slot_response_size) {
	
			writeDebug("No slot selected or invalid slot");
			$do_record_request = 0;
		}else{
			$ShowDetails = parseSlotData($CurrentSlot);
		}
	}
}



#-------------------------------------------------------------------------------------
# Make Record Request
#-------------------------------------------------------------------------------------


if ($do_record_request) {

	$ShowDetails = parseSlotData($CurrentSlot);
	$RecordRequest = processSlotResponse($CurrentSlot,$inp_quality);
	
	if ($debug) {
		writeDebug("Requesting Show to Be Recorded");
	}

	$RecordRequestResponse = recordShow($ReplayTV,$RecordRequest);

	if ($RecordRequestResponse == -1) {
		displayHeading("Request Failed");
		writeDebug("Error contacting DVR at $ReplayTV.");
	}

	if ($RecordRequestResponse == 0) {
		displayHeading("Request Failed");
		writeDebug("Record show request failed on DVR at $ReplayTV.");
	}

	if ($RecordRequestResponse == 1) {
		displayHeading("Request Confirmed");
		writeDebug("$ShowDetails has been scheduled on DVR at $ReplayTV.");
		if (length($inp_return_url) > 0) {
			$inp_return_url .= "&UPDATE=$ReplayTV";
		}
	}

	if ($RecordRequestResponse == 2) {
		displayHeading("Request Failed");
		writeDebug("Record show for $ShowDetails not requested to DVR at $ReplayTV.");
	}

}

#-------------------------------------------------------------------------------------
# Create Return Link
#-------------------------------------------------------------------------------------

if (length($inp_return_url) > 0) {
	print "<p><a href=\"$inp_return_url\">$inp_return_text</a><p>";
}else{
	$url_parms = "";
	addParameter("state","start");
	print "<p><a href=$scriptdir/$schedulename$url_parms>New</a><p>";
}

$finished = time;
$runtime = $finished - $started;
$now = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );


writeDebug("Job finished at $now ($runtime seconds)");

writeDebug("********************************************************");


&ShowHTTPFooter;

exit(1);



#-----------------------------------------------------------------
#
# Functions
#
#-----------------------------------------------------------------


#---------------------------------------------------------------------------------------
sub LoadValues {
	#
	# Load Hard Coded Values for Special Purposes (like me testing)
	#
	# ------------------------------------------------------------------------------
	
	$ReplayTV = "replay.sgc.logh.net";	# FQDN or IP of the Replay 

	$inp_manual = 0;			# Manual Recording?
	
	$inp_year = 2003;			# Year of Recording
	$inp_month = 6;				# Month of Recording
	$inp_day = 13;				# Day of Recording
	$inp_hour = 21;				# Hour of Recording  (0-23)
	$inp_minute = 00;			# Minute of Recording
	$inp_length = 60;			# Length (Minutes) 
	$inp_quality = 1;			# Quality (2 Low, 1 Med, 0 High)
	$inp_guaranteed = 0;			# Delete For New Episodes/Keep Until I Delete
	$inp_recurring = 0;			# Recurring
	$inp_daysofweek = 127;			# Days of the Week Bitmask (127 for all)
						#
						# SU MO TU WE TH FR SA
						# 1  2  4  8  16 32 64
						#
	$inp_keep = 1;				# Number of Episodes to Keep 
	$inp_isgmt = 0;				# Is Recording Time Already GMT?
	$inp_firstrun = 0;			# Record First Run Episodes Only?
	$inp_category = 255;			# Category to Use (use 255 for ALL SHOWS)


	# Required for REGULAR RECORDINGS only

	$inp_title = "Stargate SG-1";		# Used for Regular Lookups
						# eg. Stargate SG-1


	# Required for MANUAL RECORDINGS only

	$inp_channel = "SCIFIP(Cable)";		# Used for Manual Lookups
						# eg. SCIFIP(Cable)

	# Optional Fields

	$inp_tuning = 0;			# Optional and often no effect whatsoever
	$inp_postpad = 0;
	$inp_prepad = 0;
	$inp_inputsource = 3;			# Almost always tuner
	
	return;
}

#-----------------------------------------------------------------
sub DisplayOptions {
	#
	# Display Running Configuration (this is mostly for debugging purposes and the
	#				 output is not very pretty.)
	#
	# ------------------------------------------------------------------------------

	writeDebug("\nSelected Options");
	writeDebug("     ReplayTV: $ReplayTV");
	writeDebug("    Is Manual: $inp_manual");
	writeDebug("   Event Time: $inp_month/$inp_day/$inp_year $inp_hour:$inp_minute");
	writeDebug("       Length: $inp_length");
	writeDebug("      Quality: $inp_quality");
	writeDebug("Is Guaranteed: $inp_guaranteed");
	writeDebug(" Is Recurring: $inp_recurring");
	writeDebug("         Days: $inp_daysofweek");
	writeDebug("         Keep: $inp_keep");
	writeDebug("    First Run: $inp_firstrun");
	writeDebug("     Category: $inp_category");
	writeDebug("  Record Type: $inp_recordtype");
	if ($inp_manual) {
		writeDebug("      Channel: $inp_channel");
	}else{
		writeDebug("        Title: " . &converttohtml($inp_title));
	}		
	writeDebug("       Tuning: $inp_tuning");
	writeDebug("      Pre Pad: $inp_prepad");
	writeDebug("     Post Pad: $inp_postpad\n");
	writeDebug(" Input Source: $inp_inputsource\n");
	return;

}

#-----------------------------------------------------------------
sub GetWebData {
	#
	# Get Show Data via CGI
	#
	#---------------------------------------------------------

	$ReplayTV = $input::REPLAYTV;

	$inp_manual = int $input::ISMANUAL;		# Recording Type
							# 0 Regular  1 Manual

	$inp_year = int $input::YEAR;			# Year of Recording
	$inp_month = int $input::MONTH;			# Month of Recording
	$inp_day = int $input::DAY;			# Day of Recording
	$inp_hour = int $input::HOUR;			# Hour of Recording
	$inp_minute = int $input::MINUTE;		# Minute of Recording
	$inp_length = int $input::LENGTH;		# Running Time in Minutes

	$inp_quality = int $input::QUALITY;		# Quality Level (2 Standard, 1 Medium, 0 High)
	$inp_guaranteed = int $input::GUARANTEED;	# Delete For New Episodes/Keep Until I Delete
	$inp_recurring = int $input::RECURRING;		# Recurring
	$inp_firstrun = int $input::FIRSTRUN;		# Record First Run Episodes Only?
	$inp_keep = int $input::KEEP;			# Episodes to Keep

		
							# DAYS OF THE WEEK Mask
	$inp_SU = $input::SUN;				# 1
	$inp_MO = $input::MON;				# 2
	$inp_TU = $input::TUE;				# 4
	$inp_WE = $input::WED;				# 8
	$inp_TH = $input::THU;				# 16
	$inp_FR = $input::FRI;				# 32
	$inp_SA = $input::SAT;				# 64

	$inp_recordtype = int $input::RECORDTYPE;
	
	if ($inp_recordtype == 1) {
		# First Run and Repeats
		$inp_firstrun = 0;
		$inp_recurring = 1;
	}		

	if ($inp_recordtype == 2) {
		# First Run 
		$inp_firstrun = 1;
		$inp_recurring = 1;
	}		

	if ($inp_recordtype == 3) {
		# This Show Only
		$inp_firstrun = 0;
		$inp_recurring = 0;
	}		



	# Exclusive to REGULAR RECORDINGS

	$inp_category = int $input::CATEGORY;		# Category to Use (use 0 for ALL SHOWS)
	$inp_title = $input::SHOWTITLE;			# Used for Regular Lookups
							# eg. Stargate SG-1

	$inp_title = convertfromhtml($inp_title);
	
	# Exclusive to MANUAL RECORDINGS

	$inp_channel = $input::CHANNEL;			# Used for Manual Lookups
							# eg. SCIFIP(Cable)

	$inp_inputsource = $input::INPUTSOURCE;		# Input Source
	
	if ($inp_inputsource eq "") {
		$inp_inputsource = 3;			# Tuner
	}

	# OPTIONAL SETTINGS

	$inp_isgmt = 0;					# set to 1 to skip GMT convert
	$inp_tuning = int $input::TUNING;		# Channel Number
	$inp_postpad = int $input::POSTPAD;		# After Padding (Minutes)
	$inp_prepad = int $input::PREPAD;		# Before Padding (Minutes)
	

	$inp_return_url = $input::RETURNURL;		# Special Applications
	$inp_return_text = $input::RETURNTEXT;		# Special Applications


	# Process Options


	if ($inp_SU) {
		$inp_daysofweek = $inp_daysofweek + 1;
	}

	if ($inp_MO) {
		$inp_daysofweek = $inp_daysofweek + 2;
	}

	if ($inp_TU) {
		$inp_daysofweek = $inp_daysofweek + 4;
	}

	if ($inp_WE) {
		$inp_daysofweek = $inp_daysofweek + 8;
	}

	if ($inp_TH) {
		$inp_daysofweek = $inp_daysofweek + 16;
	}

	if ($inp_FR) {
		$inp_daysofweek = $inp_daysofweek + 32;
	}

	if ($inp_SA) {
		$inp_daysofweek = $inp_daysofweek + 64;
	}

	$showpdaformat = int $input::SHOWPDAFORMAT;


	return;
}



#---------------------------------------------------------------------------------------
# WEB FORM Generation
#---------------------------------------------------------------------------------------

#----------------------------------------------------
sub FormStart{
	print "<p>You may schedule a: <br>\n<UL>";
	$url_parms = "";
	addParameter("state","manual");
	print "<LI><a href=$scriptdir/$schedulename$url_parms>Manual Recording</a><br>\n";
	$url_parms = "";
	addParameter("state","regular");
	print "<LI><a href=$scriptdir/$schedulename$url_parms>Regular Recording</a><br>\n";
	print "</UL><p>\n";
	return;
}

#----------------------------------------------------
sub FormManual{
	displayHeading("Manual Recording\n");

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
						localtime(time); 
	$year += 1900; 
	$mon++;

	my $lastyear = $year - 1;

	$url_parms = "";
	addParameter("state","slotrequest");
	print "<form method=POST action=$scriptdir/$schedulename$url_parms>\n";
	print "<input type=\"hidden\" name=\"ISMANUAL\" value=\"1\">\n";
	print "<table>\n";

	# Select ReplayTV

	print "<tr>\n";
	print "<td align=right><B>ReplayTV:</B></td>\n";
	print "<td><select size=\"1\" name=\"REPLAYTV\">";
	for ( split /;/, $replaylist ) {
		/;/;
		($rtv_unit,$rtv_label) = split(',', $_, 2);
		if ($rtv_label eq $defaultreplaytv) {
			print "<option value=\"$rtv_unit\" selected>$rtv_label</option>\n";
		}else{
			print "<option value=\"$rtv_unit\">$rtv_label</option>\n";
		}
	}
	print "</select></td></tr>\n";

	# Select Date of Recording

	print "<tr>\n";
	print "<td align=right><B>Date:</B></td>\n";
	print "<td>\n";

	print "<select size=\"1\" name=\"MONTH\">\n";
	selectMonth($mon);
	print "</select>\n";
	
	print "<select size=\"1\" name=\"DAY\">\n";
	selectDay($mday,31);
	print "</select>\n";

	print "<select size=\"1\" name=\"YEAR\">\n";
	selectYear($year,$year+2);
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr>\n";
	print "<td align=right><B>Time:</B></td>\n";
	print "<td>\n";
	print "<select size=\"1\" name=\"HOUR\">\n";
	selectNumbers($hour,24,0);
	print "</select>\n";
	print ":";
	print "<select size=\"1\" name=\"MINUTE\">\n";
	print "<option value=\"0\">00</option>\n";
	print "<option value=\"5\">05</option>\n";
	print "<option value=\"15\">15</option>\n";
	print "<option value=\"30\">30</option>\n";
	print "<option value=\"45\">45</option>\n";
	print "<option value=\"55\">55</option>\n";
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr>\n";
	print "<td align=right><B>Record for</B></td>\n";
	print "<td>\n";
	print "<select size=\"1\" name=\"LENGTH\">\n";
	print "<option value=\"15\">15 Minutes</option>\n";
	print "<option value=\"30\" selected>30 Minutes</option>\n";
	print "<option value=\"45\">45 Minutes</option>\n";
	print "<option value=\"60\">60 Minutes</option>\n";
	print "<option value=\"75\">75 Minutes</option>\n";
	print "<option value=\"90\">90 Minutes</option>\n";
	print "<option value=\"120\">2 Hours</option>\n";
	print "<option value=\"180\">3 Hours</option>\n";
	print "<option value=\"240\">4 Hours</option>\n";
	print "</select>\n";
	print "</td></tr>\n";


	if ($systemtype == 1) {
		$systemtype = "Cable";
	}
	if ($systemtype == 2) {
		$systemtype = "DBS";
	}
	if ($systemtype == 3) {
		$systemtype = "Air";
	}
	

	print "<tr>\n";
	print "<td align=right><B>Channel:</B></td>\n";
	print "<td>\n";
	if (open(XMLTVFILE, $xmltvconfiguration)) {
		print "<select size=\"1\" name=\"CHANNEL\">\n";
		while (<XMLTVFILE>) {
			chop $_;

			if (substr($_,0,8) eq 'channel:') {
				($channel_num,$channel_label) = split(' ', substr($_,9), 2);
				print "<option value=\"$channel_label($systemtype)\">";
				print "$channel_label ($channel_num)";
				print "</option>\n";
			}
		}
		close XMLTVFILE;
		print "</select>\n";
	}else{
		print "<input type=\"text\" size=\"20\" name=\"CHANNEL\" value=\"\">";
		print "<br><small>Call Letters and System for Channel (eg. <TT>BBCA($systemtype)</TT>)</small>";
	}
	print "</td></tr>\n";
	
	print "<tr>\n";
	print "<td align=right><B>Quality:</B></td>\n";
	print "<td>\n";	
	print "<select size=\"1\" name=\"QUALITY\">\n";
	if ($defaultquality == 2) {
		print "<option value=\"2\" selected>Standard</option>\n";
	}else{
		print "<option value=\"2\">Standard</option>\n";
	}
	if ($defaultquality == 1) {
		print "<option value=\"1\" selected>Medium</option>\n";
	}else{
		print "<option value=\"1\">Medium</option>\n";
	}
	if ($defaultquality == 0) {
		print "<option value=\"0\" selected>High</option>\n";
	}else{
		print "<option value=\"0\">High</option>\n";
	}
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr><td align=right><B>Options:</B></td>\n";
	print "<td>";
	print "<input type=\"checkbox\" name=\"GUARANTEED\" value=\"1\" checked> Guaranteed\n";
	print "<input type=\"checkbox\" name=\"RECURRING\" value=\"1\"> Recurring\n";
	print "</td></tr>\n";

	print "<tr><td align=right><B>Record on </B></td>\n";
	print "<td>";
	print "<input type=\"checkbox\" name=\"SUN\" value=\"1\" checked> Sun.\n";
	print "<input type=\"checkbox\" name=\"MON\" value=\"1\" checked> Mon.\n";
	print "<input type=\"checkbox\" name=\"TUE\" value=\"1\" checked> Tue.\n";
	print "<input type=\"checkbox\" name=\"WED\" value=\"1\" checked> Wed.\n";
	print "<input type=\"checkbox\" name=\"THU\" value=\"1\" checked> Thu.\n";
	print "<input type=\"checkbox\" name=\"FRI\" value=\"1\" checked> Fri.\n";
	print "<input type=\"checkbox\" name=\"SAT\" value=\"1\" checked> Sat.\n";
	print "</td></tr>\n";

	print "<tr><td align=right><B>Episodes to Keep:</B></td>\n";
	print "<td>";
	print "<select size=\"1\" name=\"KEEP\">";
	selectNumbers($defaultkeep,10,1);
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr><td></td><td>";
	if (length($icon_schedule) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_schedule\" ALT=\"Schedule\">\n";
	}else{
		print "\n<input type=submit value=Schedule name=SUBMIT>\n";
	}
	print "</form><p>";
	print "</td></tr></table>";

	return;
}

#----------------------------------------------------
sub FormRegular{

	displayHeading("Regular Recording\n");

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
						localtime(time); 
	$year += 1900; 
	$mon++;

	my $lastyear = $year - 1;

	$url_parms = "";
	addParameter("state","slotrequest");
	print "<form method=POST action=$scriptdir/$schedulename$url_parms>\n";
	print "<input type=\"hidden\" name=\"ISMANUAL\" value=\"0\">\n";
	print "<table>\n";

	# Select ReplayTV

	print "<tr>\n";
	print "<td align=right><B>ReplayTV:</B></td>\n";
	print "<td><select size=\"1\" name=\"REPLAYTV\">";
	for ( split /;/, $replaylist ) {
		/;/;
		($rtv_unit,$rtv_label) = split(',', $_, 2);
		if ($rtv_unit eq $defaultreplaytv) {
			print "<option value=\"$rtv_unit\" selected>$rtv_label</option>\n";
		}else{
			print "<option value=\"$rtv_unit\">$rtv_label</option>\n";
		}
	}
	print "</select></td></tr>\n";

	# Select Date of Recording

	print "<tr>\n";
	print "<td align=right><B>Date:</B></td>\n";
	print "<td>\n";

	print "<select size=\"1\" name=\"MONTH\">\n";
	selectMonth($mon);
	print "</select>\n";
	
	print "<select size=\"1\" name=\"DAY\">\n";
	selectDay($mday,31);
	print "</select>\n";

	print "<select size=\"1\" name=\"YEAR\">\n";
	selectYear($year,$year+2);
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr>\n";
	print "<td align=right><B>Time:</B></td>\n";
	print "<td>\n";
	print "<select size=\"1\" name=\"HOUR\">\n";
	selectNumbers($hour,24,0);
	print "</select>\n";
	print ":";
	print "<select size=\"1\" name=\"MINUTE\">\n";
	print "<option value=\"0\">00</option>\n";
	print "<option value=\"5\">05</option>\n";
	print "<option value=\"15\">15</option>\n";
	print "<option value=\"30\">30</option>\n";
	print "<option value=\"45\">45</option>\n";
	print "<option value=\"55\">55</option>\n";
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr>\n";
	print "<td align=right><B>Record for</B></td>\n";
	print "<td>\n";
	print "<select size=\"1\" name=\"LENGTH\">\n";
	print "<option value=\"15\">15 Minutes</option>\n";
	print "<option value=\"30\" selected>30 Minutes</option>\n";
	print "<option value=\"45\">45 Minutes</option>\n";
	print "<option value=\"60\">60 Minutes</option>\n";
	print "<option value=\"75\">75 Minutes</option>\n";
	print "<option value=\"90\">90 Minutes</option>\n";
	print "<option value=\"120\">2 Hours</option>\n";
	print "<option value=\"180\">3 Hours</option>\n";
	print "<option value=\"240\">4 Hours</option>\n";
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr><td align=right><B>Pad Before:</B></td>\n<td><input type=\"text\" size=\"3\" name=\"PREPAD\" value=\"0\"> minutes</td></tr>\n";
	print "<tr><td align=right><B>Pad After:</B></td>\n<td><input type=\"text\" size=\"3\" name=\"POSTPAD\" value=\"0\"> minutes</td></tr>\n";
	print "</td></tr>\n";

	print "<tr>\n";
	print "<td align=right><B>Title:</B></td>\n";
	print "<td>\n";
	print "<input type=\"text\" size=\"50\" name=\"SHOWTITLE\" value=\"\">";
	print "</td></tr>\n";

	print "<tr>\n";
	print "<td align=right><B>Quality:</B></td>\n";
	print "<td>\n";	
	print "<select size=\"1\" name=\"QUALITY\">\n";
	if ($defaultquality == 2) {
		print "<option value=\"2\" selected>Standard</option>";
	}else{
		print "<option value=\"2\">Standard</option>";
	}
	if ($defaultquality == 1) {
		print "<option value=\"1\" selected>Medium</option>";
	}else{
		print "<option value=\"1\">Medium</option>";
	}
	if ($defaultquality == 0) {
		print "<option value=\"0\" selected>High</option>";
	}else{
		print "<option value=\"0\">High</option>";
	}
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr><td align=right><B>Options:</B></td>\n";
	print "<td>";
	print "<input type=\"checkbox\" name=\"GUARANTEED\" value=\"1\" checked> Guaranteed\n";
	print "<input type=\"checkbox\" name=\"RECURRING\" value=\"1\"> Recurring\n";
	print "<input type=\"checkbox\" name=\"FIRSTRUN\" value=\"1\"> First Run Only\n";
	print "</td></tr>\n";

	print "<tr><td align=right><B>Record on </B></td>\n";
	print "<td>";
	print "<input type=\"checkbox\" name=\"SUN\" value=\"1\" checked> Sun.\n";
	print "<input type=\"checkbox\" name=\"MON\" value=\"1\" checked> Mon.\n";
	print "<input type=\"checkbox\" name=\"TUE\" value=\"1\" checked> Tue.\n";
	print "<input type=\"checkbox\" name=\"WED\" value=\"1\" checked> Wed.\n";
	print "<input type=\"checkbox\" name=\"THU\" value=\"1\" checked> Thu.\n";
	print "<input type=\"checkbox\" name=\"FRI\" value=\"1\" checked> Fri.\n";
	print "<input type=\"checkbox\" name=\"SAT\" value=\"1\" checked> Sat.\n";
	print "</td></tr>\n";

	print "<tr><td align=right><B>Episodes to Keep:</B></td>\n";
	print "<td>";
	print "<select size=\"1\" name=\"KEEP\">";
	selectNumbers($defaultkeep,10,1);
	print "</select>\n";
	print "</td></tr>\n";

	print "<tr><td></td><td>";
	if (length($icon_schedule) > 0) {
		print "\n<input type=image src=\"$imagedir/$icon_schedule\" ALT=\"Schedule\">\n";
	}else{
		print "\n<input type=submit value=Schedule name=SUBMIT>\n";
	}
	print "</form><p>";
	print "</td></tr></table>";

	return;
}

