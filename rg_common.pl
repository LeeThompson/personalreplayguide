#!/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
#  $Id: rg_common.pl,v 1.4 2003/07/23 03:03:11 pvanbaren Exp $
#
# COMMON FUNCTIONS
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

use Time::Local;

my $_version = "Personal ReplayGuide|Common Function Library|1|1|223|Lee Thompson,Kanji T. Bates";

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


#-----------------------------------------------------------------
sub converttext {
	#
	# Convert Text to HexStrings
	#
	# Parameters: Text String, Size of String (Bytes)
	#
	# Returns: Hex Encoded String with Zero Fills
	#
	#---------------------------------------------------------

	my $ascii = shift;
	my $size = shift;
	my $retvalue = "";
	my $char = "";

	$flen = $size;
	$fpos = 0;

	do {
		$char = ord substr($ascii,$fpos,1);
		$retvalue .= converthex($char,2);
						
		$fpos++;

	} while ($fpos < $flen);
	
	return $retvalue;

}

#-----------------------------------------------------------------
sub decodehex {
	#
	# Convert HexString to Binary ASCII
	#
	# Parameters: Hex String (terminates at a null or at character x if given)
	#
	# Returns: Binary Data 
	#
	#---------------------------------------------------------
	
	my $hexstring = shift;
	my $stopat = int shift;
	my $binarystring = "";

	my $fpos = 0;
	my $flen = length($hexstring);
	my $stoponnull = 1;

	if ($stopat > 0) {
		$flen = $stopat;
		$stoponnull = 0;
	}

	my $blen = int($flen / 2);


	my $hexvalue = "";
	my $value = "";
	my $binvalue = "";

	do {
		$hexvalue = substr($hexstring,$fpos,2);
		
		$value = hex $hexvalue;
		$binvalue = pack("C",$value);

		$binarystring .= $binvalue;

		$fpos++;
		$fpos++;

		if ($stoponnull) {
			if ($hexvalue eq "00") {	
				$fpos = $flen;
			}
		}

	} while ($fpos < $flen);

	return $binarystring;
}

#-----------------------------------------------------------------
sub converthex {
	#
	# Convert Values to HexString
	#
	# Parameters: Decimal Value, Number of Bytes
	#
	# Returns: Hex Encoded String
	#
	#---------------------------------------------------------

	my $value = int shift;
	my $size = int shift;
	my $hexvalue = "";

	$hexvalue = uc sprintf("%x",$value);

	if ($size == 1) {
		$hexvalue = uc sprintf("%01x",$value);
	}

	if ($size == 2) {
		$hexvalue = uc sprintf("%02x",$value);
	}

	if ($size == 4) {
		$hexvalue = uc sprintf("%04x",$value);
	}

	if ($size == 8) {
		$hexvalue = uc sprintf("%08x",$value);
	}

	if ($size == 16) {
		$hexvalue = uc sprintf("%016x",$value);
	}

	return $hexvalue;

}

#---------------------------------------------------------------------------------------
sub converttohtml {
	#
	# Convert special characters to HTML 
	#
	# Parameters:	String
	# Returns: 	String (Altered)
	#
	# ------------------------------------------------------------------------------

	my $tempvar = shift;

    	$tempvar =~ s/\&/\&amp;/g;
	$tempvar =~ s/\'/\&apos;/g;
	$tempvar =~ s/\"/\&apos;/g;
	$tempvar =~ s/\</\&lt;/g;
	$tempvar =~ s/\>/\&gt;/g;

	return $tempvar;

}

#---------------------------------------------------------------------------------------
sub convertfromhtml {
	#
	# Convert special characters from HTML 
	#
	# Parameters:	String
	# Returns: 	String (Altered)
	#
	# ------------------------------------------------------------------------------

	my $tempvar = shift;

    	$tempvar =~ s/\&amp;/\&/g;
	$tempvar =~ s/\&apos;/\'/g;
	$tempvar =~ s/\&quot;/\"/g;
	$tempvar =~ s/\&lt;/\</g;				
	$tempvar =~ s/\&gt;/\>/g;

	return $tempvar;

}

#---------------------------------------------------------------------------------------
sub renderhtml($) {
	#
	# Convert special characters from HTML 
	#
	# Parameters:	String
	# Returns: 	String (Altered)
	#
	# ------------------------------------------------------------------------------

	my $tempvar = shift;

	$tempvar =~ s/\&apos;/\'/g;

	return $tempvar;

}

#---------------------------------------------------------------------------------------
sub buildcommastring {
	#
	# Build comma delimited string
	#
	# Parameters: stringtoaddto
	#	      addedvalue
	#
	# Returns: longer string
	#----------------------------------------------------------------------
		
	my $oldstring = shift;
	my $newstring = shift;

	if ($newstring eq $null) {
		return $oldstring;
	}

	if ($oldstring ne $null) {
		$oldstring .= ",";
	}

	$newstring = $oldstring . $newstring;

	return $newstring;

}

#----------------------------------------------------------------------
sub trimstring {
	#
	# Trim whitespace from a string (both ends)
	#
	# Parameters:	String
	# Returns: 	String (Altered)
	#
	# ------------------------------------------------------------------------------

	my $tempvar = shift;

    	$tempvar =~ s/^\s+//;
    	$tempvar =~ s/\s+$//;

	return $tempvar;

}


#----------------------------------------------------------------------
sub removedashes {
	#
	# Remove dashes from a string
	#
	# Parameters:	String
	# Returns: 	String (Altered)
	#
	# ------------------------------------------------------------------------------

	my $tempvar = shift;

    	$tempvar =~ s/-//g;

	return $tempvar;
}


#----------------------------------------------------------------------
sub removeescapes {
	#
	# Remove HTML escapes from a string
	#
	# Parameters:	String
	# Returns: 	String (Altered)
	#
	# ------------------------------------------------------------------------------

	my $tempvar = shift;

    	$tempvar =~ s/%20/ /g;

	return $tempvar;
}

#---------------------------------------------------------------------------------------
sub as_hhmm {
	#
	# Show a Time As HH:MM AM/PM
	#
	# Parameters: epochseconds
	# Returns: human readable string
	#
	# ------------------------------------------------------------------------------

	my $string = as_time_string(shift);
	my $hour = substr($string,8,2);
	my $minute = substr($string,10,2);
	my $pm = 0;

	$hour = int $hour;

	if ($hour > 11) {
		$pm = 1;
		$hour = $hour - 12;
	}

	if ($hour == 0) {
		$hour = 12;
	}

	$string = "$hour:$minute ";

	if ($pm) {
		$string .= "PM";
	}else{
		$string .= "AM";
	}

	return $string;
}



#---------------------------------------------------------------------------------------
sub as_ampm {
	#
	# Show an Hour As HH AM/PM
	#
	# Parameter: Hour (24 hour clock)
	# Returns: String
	#
	# ------------------------------------------------------------------------------

	my $hour = int shift;
	my $pm = 0;

	if ($hour > 24) {
		return;
	}

	if ($hour < 0) {
		return;
	}
		

	if ($hour > 11) {
		$pm = 1;
		$hour = $hour - 12;
	}

	if ($hour == 0) {
		$hour = 12;
	}

	$string = sprintf("%02d",$hour);
	$string .= ":00 ";

	if ($pm) {
		$string .= "PM";
	}else{
		$string .= "AM";
	}

	return $string;
}


#---------------------------------------------------------------------------------------
sub as_time_string {
	#
	# Converts epoch seconds to a time string (eg. 200403181942)
	# 
	# Parameters:	epoch seconds
	# Returns: 	string
	#
	# ------------------------------------------------------------------------------
	
	(my $seconds,my $minute,my $hour,my $day,my $month,my $year,my $wday,my $yday) = localtime(shift);
	$year += 1900;  
	$month++;

	my $string = "";

	$seconds = sprintf("%02d",$seconds);
	$minute = sprintf("%02d",$minute);
	$hour = sprintf("%02d",$hour);
	$day = sprintf("%02d",$day);
	$month = sprintf("%02d",$month);
	$year = sprintf("%04d",$year);

	$string .= $year;
	$string .= $month;
	$string .= $day;
	$string .= $hour;
	$string .= $minute;
	$string .= $seconds;
	
	return $string;
}


#---------------------------------------------------------------------------------------
sub as_epoch_seconds { 
	#
	# Converts a time string to epoch seconds 
	#
	# Parameters:	String
	# Returns: 	EpochSeconds
	#
	# ------------------------------------------------------------------------------

	my($Y,$M,$D,$h,$m,$s) = unpack 'A4 A2 A2 A2 A2 A2', shift; 

	if (int $Y < 1970) {
		return 0;
	}
        if ((int $M < 1) || (int $M > 12)) {
		return 0;
	}
	if ((int $D < 1) || (int $D > 31)) {
		return 0;
	}
	return timelocal( 0, $m, $h, $D, $M - 1, $Y - 1900 ); 
}

#---------------------------------------------------------------------------------------
sub getMinutes {
	#
	# Returns the number of minutes between two epoch seconds.
	#
	# Parameters:	start,end
	# Returns: 	minutes
	#
	# ------------------------------------------------------------------------------

	my $program_start = shift;
	my $program_stop = shift;
	my $minutes = 0;

	$minutes = (as_epoch_seconds($program_stop) - as_epoch_seconds($program_start)) / 60;
	
	return $minutes;
}

#---------------------------------------------------------------------------------------
sub addParameter {
	#
	# Add CGI Parameter
	#
	# Usage: addParameter(name,value)
	# Returns: Adds to global $url_parms 
	#
	# ------------------------------------------------------------------------------
	
	my $parmname = uc shift;
	my $parmvalue = shift;

	if ($parmname eq $null) {
		writeDebug("Warning: addParameter: No name given.");
		return 0;
	}

	if ($parmvalue eq $null) {
		writeDebug("Warning: addParameter: Value set to null for parameter '$parmname'");
	}

	#----------------------------------------------------------
	# if null, start with a ? otherwise add a & and our stuff
	#----------------------------------------------------------

	unless ( $url_parms =~ /[?&]$parmname=/ ) { 
		if ($url_parms eq $null) {
					$url_parms = "\?$parmname=$parmvalue";
				}else{
					$url_parms .= "\&$parmname=$parmvalue";
		}
	}

	return 1;
	
}

#---------------------------------------------------------------------------------------
sub getParameter {
	#
	# Get CGI Parameter
	#
	# Usage: getParameter(name)
	# Returns: Parameter or null
	#
	# ------------------------------------------------------------------------------
	

	my $parmname = uc shift;
	my $parameter = $null;
	my $parmvalue = $null;

	$parmvalue = param($parmname);

	($junk,$parameter) = split(/=/,$parmvalue);

	if ($parameter eq $null) {
		# if split was unsuccessful, revert.
		$parameter = $parmvalue;
	}
	
	if ($parameter eq $null) {
		# if we still have nothing, try to just get the query 
		$parmvalue = $ENV{'QUERY_STRING'};

		# attempt the split again
		
		($junk,$parameter) = split(/=/,$parmvalue);

		if ($junk ne $parmname) {
			#
			# if it's not the right one, zero it.
			$parameter = $null;		
		}

		
	}
	
	return $parameter;
	
}

#---------------------------------------------------------------------------------------
sub ShowHTTPHeader {
	#
	# Display HTTP Header
	#
	# Usage &ShowHTTPHeader or showHTTPHeader()
	#
	# ------------------------------------------------------------------------------

	$htmlmode = 1;

	if (uc $ENV{PERL_SEND_HEADER} eq "ON") {
		#-----------------------------------
		# Apache with ModPerl, override conf
		#-----------------------------------

		$supresshttpheader = 1;
		$supresscontenttype = 1;
	}

	if ($ENV{SERVER_SOFTWARE} =~ /Apache/i ) {
		#-----------------------------------
		# Apache 
		#-----------------------------------

		$supresshttpheader = 1;
	}

	if (!$supresshttpheader) {
		print "HTTP/1.0 200 OK\n";
	}

	if (!$supresscontenttype) {
		print "Content-Type: text/html\n\n";
	}
	
	return 1;
}

#---------------------------------------------------------------------------------------
sub ShowHTTPFooter {

	#-------------------------------------------------------------------
	# Print the footer, if you want to add your own text at the bottom
	# of every page, this is the place.
	#-------------------------------------------------------------------

	if ($verbose eq "") {
		my $verbose = 1;
	}

	if ($htmlmode) {
		print "</center>\n";
		print "</BODY></HTML>\n";
	}else{
		if ($verbose) {
			print "\n";
		}
	}

	$htmlmode = 0;

	return 1;
}

#---------------------------------------------------------------------------------------
sub getPathAndFile {
	#
	# Parameters: Pathname
	# Returns; Path,File
	#
	# ------------------------------------------------------------------------------

	my $pathname = shift;
	my @data = "";
	my $dataline = "";
	my $path = "";
	my $filename = "";
	my $count = 0;

	if ($pathname eq "") {
		return;
	}

	if ($pathname =~ /\// ) {
		(@data) = split(/\//,$pathname);
	}

	if ($pathname =~ /\\/ ) {
		(@data) = split(/\\/,$pathname);
	}
	
	$count = countElements(@data);
	
	if ($count) {
		my $ctr = 0;
		$filename = $data[$count];
		foreach $dataline ( @data ) {
			$ctr++;
			if ($ctr <= $count) {
				if ($ctr > 1) {
					$path .= "/";
				}
				$path .= $dataline;
			}
		}
	}else{
		$filename = $pathname;
	}


	if ($path eq "") {
		$path = ".";
	}

	return ($path,$filename);

}

#---------------------------------------------------------------------------------------
sub abend {
	#
	# Used for Abnormal Termination
	# Text reason is the only parameter.  
	#
	# NOTE: It will NOT return from this function!
	#
	# ------------------------------------------------------------------------------

	my $outputtext = shift;
	(my $debug_package, my $debug_filename, my $debug_line, my $debug_subroutine, my $debug_hasargs, my $debug_wantarray, my $debug_evaltext, my $debug_isrequire) = caller(0);
	
	displayText($outputtext);
	writeLogFile("********************************************************");
	if ($outputtext =~ /\n/) {
		foreach my $outtext ( split(/\n/, $outputtext ) ) {
			writeLogFile("***** " . convertfromhtml($outtext));		
		}
	}else{
		writeLogFile("***** " . convertfromhtml($outputtext));	
	}	
	
	writeLogFile("***** Program Abend: $debug_filename at $debug_line");
	
	if ($htmlmode) {
		print "<p><B>Program terminated due to fatal error or condition.</B>";
	}else{
		print "\nProgram terminated due to fatal error or condition.\n";
	}

	if ($htmlmode) {
		print "<PRE>***** Execute halted for $debug_filename at $debug_line</PRE><p>";
		print "</BODY></HTML>\n";
	}else{
		print "***** Execute halted for $debug_filename at $debug_line\n";
	}

	writeDebug("********************************************************");

	exit(0);
}

#---------------------------------------------------------------------------------------
sub displayHeading {
	#
	# Display Heading (Wrapper for DisplayText)
	#
	# Parameters: Text, [Mode]
	#
	# Modes: 0 Normal, 1 Debug, 2 Literal Debug
	#
	# ------------------------------------------------------------------------------

	my $outputtext = shift;
	my $debugmode = int shift;
	my $printstring = "";

	if ($size_section eq "") {
		$size_section = "<H2>";
	}

	if ($htmlmode) {
		print "<$size_section>";
		if ($font_title ne "") {
			print "<font face=\"$font_title\">";
		}
		displayText($outputtext,$debugmode);
		print "</$size_section>";
		print "<p>";
		if ($font_title ne "") {
			print "</font>";
		}

	}else{
		displayText($outputtext,$debugmode);
	}

	return;
}

#---------------------------------------------------------------------------------------
sub displayText {
	#
	# Display Text
	#
	# Parameters: Text[,Mode][,No \n]
	#
	# Modes: 0 Normal, 1 Debug, 2 Literal Debug
	#
	# ------------------------------------------------------------------------------

	my $outputtext = shift;
	my $debugmode = int shift;
	my $nocrlf = int shift;
	my $printstring = "";

	if ($htmlmode) {
		if ($debugmode) {
			if ($debugmode == 1) {
				$printstring = "<PRE>DEBUG:: $outputtext</PRE>";
			}
			if ($debugmode == 2) {
				$printstring = "<PRE>$outputtext</PRE>";
			}
		}else{
			if ($nocrlf) {
				$printstring = $outputtext;
			}else{
				$printstring = $outputtext . "\n";
				$printstring = converttohtml($outputtext);
				$printstring =~ s/\r//g;	# Eat LF
				$printstring =~ s/\n/<br>/g;	# Convert CR to Paragraph
			}
		}
	}else{
		if ($debugmode) {
			if ($debugmode == 1) {
				$printstring = "DEBUG:: $outputtext";
			}
			if ($debugmode == 2) {
				$printstring = "$outputtext";
			}
		}else{
			$printstring = $outputtext;
		}

	}


	if ($nocrlf) {
		$printstring =~ s/\r//g;
		$printstring =~ s/\n//g;
		
		print "$printstring";
	}else{
		print "$printstring\n";
	}

	return;		

}


#----------------------------------------------------
sub selectMonth{
	#
	# Display an HTML FORM SELECT range for Month
	#
	#
	# Parameter: month (numeric)
	#
	# ------------------------------------------------------------------------------

	my $current_month = int shift;
	my $ctr = 1;

	do {
		print "<option value=\"$ctr\"";
		if ($ctr == $current_month) {
			print " selected";
		}
		print ">";
		if ($ctr == 1) {
			print "Jan";
		}		
		if ($ctr == 2) {
			print "Feb";
		}		
		if ($ctr == 3) {
			print "Mar";
		}		
		if ($ctr == 4) {
			print "Apr";
		}		
		if ($ctr == 5) {
			print "May";
		}		
		if ($ctr == 6) {
			print "Jun";
		}		
		if ($ctr == 7) {
			print "Jul";
		}		
		if ($ctr == 8) {
			print "Aug";
		}		
		if ($ctr == 9) {
			print "Sep";
		}		
		if ($ctr == 10) {
			print "Oct";
		}		
		if ($ctr == 11) {
			print "Nov";
		}		
		if ($ctr == 12) {
			print "Dec";
		}		
		print "</option>\n";
		$ctr++;
	} while ($ctr < 13);

	return;
}

#----------------------------------------------------
sub selectDay {
	#
	# HTML FORM SELECT for Days - wrapper for selectNumbers
	#
	# Parameters: current day
	#   	      maximum day
	#
	# ------------------------------------------------------------------------------

	my $current_day = int shift;
	my $maximum_day = int shift;

	selectNumbers($current_day,$maximum_day+1,1);

	return;
}

#----------------------------------------------------
sub selectYear {
	#
	# Display a Year HTML FORM SELECT
	#
	# Parameters: current year
	#	      maximum year (-1)
	#
	# ------------------------------------------------------------------------------

	my $current_year = int shift;
	my $maximum_year = int shift;
	my $ctr = $current_year;

	do {
		print "<option value=\"$ctr\"";
		if ($ctr == $current_year) {
			print " selected";
		}
		print ">";
		print $ctr;
		print "</option>\n";
		$ctr++;
	} while ($ctr < $maximum_year);
	
	return;

}

#----------------------------------------------------
sub selectNumbers {
	#
	# Display an HTML SELECT for a range of numbers
	#
	# Parameters: current number (selected)
	#	      maximum number (-1)
	#	      start number
	#
	# ------------------------------------------------------------------------------

	my $current_number = int shift;
	my $maximum_number = int shift;
	my $start_number = int shift;

	my $ctr = $start_number;

	do {
		print "<option value=\"$ctr\"";
		if ($ctr == $current_number) {
			print " selected";
		}
		print ">";
		printf "%2d",$ctr;
		print "</option>\n";
		$ctr++;
	} while ($ctr < $maximum_number);
	
	return;

}

#----------------------------------------------------
sub daysInMonth {
	#
	# Determine the Number of Days in a Month 
	# Parameters: Year, Month
	# Returns: Days
	#
	# ------------------------------------------------------------------------------

    	my $year = int shift;
    	my $month = int shift;	

	if ($year < 1970) {
		return 0;
	}

	if (($month < 1) || ($month > 12)) {
		return 0;
	}

    	$year   -= 1900;
    	$year   +=    1 unless $month %= 12;
    	my $date = timelocal( 0, 0, 12, 1, $month, $year );
    	my $days = ( localtime( $date - 86_400 ) )[3];
    	return $days;
}

#----------------------------------------------------
sub displaytime {
	#
	# Display the Time in a Human Format
	#
	# Parameter: Time String
	# Returns; Display String
	#
	# ------------------------------------------------------------------------------

	my $timestring = shift;
	my $dsp_string = "";


	$dsp_string = substr($timestring,4,2) . "/" . substr($timestring,6,2) . "/" . substr($timestring,0,4) . " ";
	$dsp_string .= as_hhmm(as_epoch_seconds($timestring));

	return $dsp_string;
}


#----------------------------------------------------
sub countElements {
	#
	# Counts the number of entries in an array
	# delimited array.
	#
	# Parameters: Array
	# Returns: Number of Elements
	#
	# ------------------------------------------------------------------------------

	my $ctr = 0;
	my $aref = "";

	foreach $aref ( @_ ) {
		$ctr++;
	}

	return ($ctr-1);
}

#----------------------------------------------------
sub countArray {
	#
	# Counts the number of entries in a comma
	# delimited array.
	#
	# Parameters: Array[,Delimiter]
	# Returns: Number of Elements
	#
	# ------------------------------------------------------------------------------

	my $carray = shift;
	my $cdelimiter = shift;
	my $ctr = 0;

	if (length($cdelimiter) < 1) {
		$cdelimiter = ",";
	}

	for ( split /$cdelimiter/, $carray ) {
		$ctr++;
	}

	return $ctr;
}

#----------------------------------------------------
sub hasAccess {
	# 
	# Determines what rights a connecting IP has
	#
	# Parameter: IP Address	
	# Usage: hasAccess(IP Address)
	# Returns TRUE or FALSE
	#
	# ------------------------------------------------------------------------------

	my $testaddress = shift;
	my $returncode = 0;

	if ($allow_list eq "ALL") {
		$returncode = 1;
	}

	if ($allow_list eq "NONE") {
		$returncode = 0;
	}

	for ( split /,/, $allow_list ) {
		/,/;
		if ($testaddress eq $_) {
			$returncode = 1;
		}
	}

	return $returncode;
}

#----------------------------------------------------
sub isPDA {
	# 
	# Determines if the remote address is a PDA
	#
	# Parameter: IP Address
	#
	# Usage: isPDA(IP Address)
	#
	# Returns TRUE or FALSE
	#
	# ------------------------------------------------------------------------------

	my $testaddress = shift;
	my $returncode = 0;

	if ($pda_list eq "ALL") {
		$returncode = 1;
	}

	if ($pda_list eq "NONE") {
		$returncode = 0;
	}

	for ( split /,/, $pda_list ) {
		/,/;
		if ($testaddress eq $_) {
			$returncode = 1;
		}
	}

	return $returncode;
}

#---------------------------------------------------------------------------------------
sub identifyLoadedModules {
	#
	# Writes loaded modules to output
	#
	# Parameter (optional): New module to id
	# (use &identifyLoadedModules or identifyLoadedModules() if not identifying a new
	# mod
	#
	#-------------------------------------------------------------------------------
	
	my $newmodule = shift;
	my $moduledata = $null;
	my $modulename = $null;
	my $currentrec = $null;
	my $prevname = $null;
	my $authorlist = $null;
	my $text = $null;
	my $flag = 0;

	foreach $currentrec (%prg_module) {
		if ($currentrec =~ /\|/) {
			$moduledata = $currentrec;
			if ($flag) {
				$flag = 2;
				$prevname = $modulename;
				
			}
		}else{
			if ($prevname ne $currentrec) {
				$modulename = $currentrec;
				$flag = 1;
			}
		}

		if ($flag == 2) {
			if (length($newmodule) > 0) {
				if ($newmodule ne $modulename) {
					$flag = 0;
				}
			}
		}

		if ($flag == 2) {
				

			(my $parent,my $desc,my $major,my $minor,my $build,my $authors) = parseModuleData($moduledata);
			$authorlist = "";
			for ( split /,/, $authors ) {
				/,/;
				$authorlist = buildcommastring($authorlist,$_);
			}
			if ($modulename =~ /\.pl/ ) {
				($modulename,$text) = split(/\.pl/, $modulename, 2);
			}
			writeDebug("$modulename v$major.$minor build $build ($desc) loaded.");
		}
		
		
		
	}
}


#---------------------------------------------------------------------------------------
sub parseModuleData {
	# 
	# Parse Module Data
	#
	# Parameter: module datastring
	#
	# Returns $parent,$desc,$major,$minor,$build,$authors
	# ------------------------------------------------------------------------------

	my $moduledata = shift;

	(my $parent,my $desc,my $major,my $minor,my $build,my $authors) = split(/\|/, $moduledata, 6);

	return ($parent,$desc,$major,$minor,$build,$authors);
		
}


#---------------------------------------------------------------------------------------
sub buildMultiWordList {
	#
	# buildMultiWordList
	#
	#
	# Parameter: Text (comma delimited)
	# Returns: nice text like "Word, Word, Word and Word."
	# ------------------------------------------------------------------------------

	my $authorstring = "";
	my $liststring = shift;
	my $wordcount = countArray($liststring);
	my $ctr = 0;

	if ($wordcount < 2) {
		return $liststring;
	}

	for ( split /,/, $liststring ) {
		/,/;
		my $wordtext = $_;
		$ctr++;
		if (($ctr > 1) && ($ctr < $wordcount)) {
			$authorstring .= ", ";
		}
		if ($ctr == $wordcount) {
			$authorstring .= " and ";
		}
		$authorstring .= $wordtext;
	}

	return $authorstring;
}

#---------------------------------------------------------------------------------------
sub writeDebug {
	#
	# Write Debug Message
	#
	#
	# Parameter: Text
	#	     no CRLF flag (optional)
	#	     Force Modulename (optional)
	#
	# Usage: WriteDebug (Message[,module])
	#
	# Returns nothing.  (NOTE: If debug is off, regular non debug text is given
	# instead)
	#
	# Module is ignored if debug is off.
	#
	# ------------------------------------------------------------------------------

	my $debug_message = shift;
	my $nocrlf = int shift;
	my $debug_module = shift;
	my $debug_subroutine = $null;
	my $debug_package = $null;
	my $debug_filename = $null;
	my $debug_line = $null;
	my $debug_hasargs = $null;
	my $debug_wantarray = $null;
	my $debug_evaltext = $null;
	my $debug_isrequire = $null;
	my $debug_outputtext = $null;
	my $text = "";
	my $debug_marker = "|";

	if ($debug < 1) {
		writeOutput($debug_message,$nocrlf);
		return 1;
	}

	($debug_package, $debug_filename, $debug_line, $debug_subroutine, $debug_hasargs, $debug_wantarray, $debug_evaltext, $debug_isrequire) = caller(0);
	my $debug_sectionname = $debug_filename;

	if ($debug_filename =~ /\.pl/ ) {
		($debug_sectionname,$text) = split(/\.pl/, $debug_filename, 2);
	}

	if ($debug_sectionname eq $null ) {
		$debug_sectionname = $debug_filename;
	}

	if ($debug_message eq $null) {
		$debug_message = "MARKER";
	}

	if (($debug_line eq $null) || ($debug_subroutine eq $null)) {
		($debug_package, $debug_filename, $debug_line, $debug_subroutine, $debug_hasargs, $debug_wantarray, $debug_evaltext, $debug_isrequire) = caller(0);
		$debug_subroutine = $debug_module;
		if ($debug_filename =~ /\.pl/ ) {
			($debug_sectionname,$text) = split(/\.pl/, $debug_filename, 2);
		}
		if ($debug_sectionname eq $null ) {
			$debug_sectionname = $debug_filename;
		}	
		if ($debug_subroutine eq $null ) {
			$debug_subroutine = $debug_sectionname;
		}
	}

	$debug_outputtext = "DEBUG|$debug_subroutine:$debug_line\:\:$debug_message";

	writeOutput($debug_outputtext,$nocrlf);

	return 1;
}

#---------------------------------------------------------------------------------------
sub writeOutput {
	# 
	# Write to STDOUT (if defined) *AND* Log file (if defined)
	#
	# If verbose is 0 and log_pathname isn't defined, you won't see a damn thing.
	# If verbose is undefined it will be forced on
	#
	# Parameter text to write with optional nocrlf flag to the STDOUT display
	# 
	# Always returns true.
	#
	#---------------------------------------------------------------------------------------

	my $outputtext = shift;
	my $nocrlf = int shift;

	if ($verbose eq $null) {
		writeLogFile("Warning: Verbose was undefined.");
		my $verbose = 1;
		
	}

	if (($verbose) && (length($outputtext) > 0)) {
		displayText($outputtext,$debug,$nocrlf);
	}
	writeLogFile($outputtext);

	return 1;
}


#---------------------------------------------------------------------------------------
sub writeLogFile {
	# 
	# Write to Log file
	#
	# (This is now a wrapper for updateLogFile which adds the ability to process \n 's
	# properly.)
	#
	# Parameter text to write
	# Always returns true.
	#
	#---------------------------------------------------------------------------------------

	my $outputtext = shift;

	if (length($log_pathname) < 1) {
		return 1;
	}

	$outputtext =~ s/\r//g;

	if ($outputtext =~ /\n/) {
		(my @outputlines) = split(/\n/,$outputtext);

		foreach $outputtext ( @outputlines ) {
			$outputtext =~ s/\n//g;
			updateLogFile($outputtext);
		}
	}else{
		updateLogFile($outputtext);
	}

	return 1;
}

#---------------------------------------------------------------------------------------
sub updateLogFile {
	# 
	# update the log file
	#
	# Parameters: filename
	#	      output buffer
	#
	#---------------------------------------------------------------------------------------

	my $outputtext = shift;

	if (length($log_pathname) < 1) {
		return 1;
	}

	if (length($outputtext) < 1 ) {
		return 1;
	}

	my $module = "";

	if ($log_module_name) {
		(my $path,my $basename) = $script_pathname =~ m|^(.*[/\\])([^/\\]+?)$|;
		if ($path eq "") {
			$basename = $script_pathname;
		}

		($module,my $junk) = split(/\.pl/,$basename);
		$module .= "\:\:";
	}

	my $log_time = strftime( "%Y-%m-%d", localtime ) . " " . strftime( "%H:%M:%S", localtime );
	
	if (open(HDEBUGFILE, ">>$log_pathname")) {
		print HDEBUGFILE "$log_time $module$outputtext\n";
		close(HDEBUGFILE);
	}

}


#---------------------------------------------------------------------------------------
sub dumpFile {
	# 
	# dump a File
	#
	# Parameters: filename
	#	      output buffer
	#	      filemode (optional) - if 1 output is binary, default is 0 (Text)
	#
	#
	# Usage: dumpFile(filename,content)
	# Returns true if successful
	#
	# (This is primarily for debugging purposes.)
	#
	#---------------------------------------------------------------------------------------

	my $filename = shift;
	my $outputtext = shift;
	my $filemode = int shift;

	if (length($filename) < 1) {
		return 1;
	}

	if (length($outputtext) < 1) {
		return 1;
	}

	if (open(HDEBUGFILE, ">>$filename")) {
		if ($filemode) {
			binmode HDEBUGFILE;
			print HDEBUGFILE $outputtext;
		}else{
			print HDEBUGFILE "$outputtext\n";
		}
		close(HDEBUGFILE);
		return 1;
	}else{
		return 0;
	}

	return 0;

}


#---------------------------------------------------------------------------------------
sub getRunningTime {
	#
	# Get Running Time
	#
	# Usage: getRunningTime(minutes[,format])
	# Returns: 0 if failed
	#
	# ------------------------------------------------------------------------------
	

	my $minutes = int shift;
	my $format = int shift;

	my $ret = "";

	if ($minutes < 0) {
		return 0;
	}

	my $hours = int $minutes / 60;
	my $remminutes = $minutes - (int $hours * 60);
	
	if ($hours) {
		if ($format == 0) {
			$ret .= $hours; 
		}
		if ($format == 1) {
			if ($hours > 1) {
				$ret .= "$hours hours"; 
			}else{
				$ret .= "$hours hour"; 
			}
		}

	}
	
	if ($format == 0) {
		$ret .= ":";
	}

	if ($format == 0) {
		$ret .= sprintf("%02d",$remminutes);
	}

	if ($format == 1) {
		if ($remminutes > 0) {
			$ret .= " $remminutes";

			if ($remminutes == 1) {
				$ret .= " minute";
			}else{
				$ret .= " minutes";
			}
		}
	}


	return $ret;
		
}

#---------------------------------------------------------------------------------------
sub doTimesOverlap($$$$) {
	#
	# Do Times Overlap
	#
	# Parameters: start time (A), end time (A), start time (B), end time (B)
	# Returns true if they overlap
	#
	# ------------------------------------------------------------------------------

	my $a_start = int shift;
 	my $a_end = int shift;
  	my $b_start = int shift;
  	my $b_end = int shift;

	if (($a_start == $b_start) && ($a_end == $b_end)) {
		return 1;
	}

	if ($a_start == $b_start) {
		return 1;
	}

  	for my $time ( $a_start, $a_end ) {
    		return 1 if $time > $b_start && $time < $b_end;
  	}
  	return 0;
}

#---------------------------------------------------------------------------------------
sub resolveHostname {
	#
	# Resolve a hostname to an IP string (X.X.X.X)
	#
	# Usage: resolve_hostname(string)
	#
	# Returns: IP address
	#
	# ------------------------------------------------------------------------------

	my $ipaddress = "";

	(my $a,my $b,my $c,my $d) = unpack('C4',gethostbyname(shift));
	$ipaddress = "$a.$b.$c.$d";
	
	if (is_ipaddress($ipaddress)) {
		return $ipaddress;		
	}else{
		return;
	}
}

#---------------------------------------------------------------------------------------
sub isIPAddress {
	#
	# Is this an IP address?
	#
	# Usage: isIPAddress(string)
	#
	# Returns: True (1) or False (0)
	#
	# ------------------------------------------------------------------------------

	my $retcode = 0;
	my $fail = 0;
	my $ctr = 0;
	my @iparray = split(/\./, shift);

	foreach my $octet ( @iparray ) {
		if ($octet =~ /^-?\d+$/) {
		}else{
			$fail = 1;
		}
		if (($octet < 0) || ($octet > 255)) {
			$fail = 1;
		}
		$ctr++;
	}

	if ($ctr != 4) {
		$fail = 1;
	}

	if ($fail) {
		$retcode = 0;
	}else{
		$retcode = 1;
	}

	return $retcode;

}


#----------------------------------------------------
sub showImage {
	#
	# Show Image
	#
	# Parameters: ImageName[,Dir,ALT,Align,Width,Height]
	#
	# Optional:
	#	      Directory (uses $imagedir if not included)
	#	      Alignment 
	#	      Width
	#	      Height
	#	      Alt Tag
	#
	# Outputs img src to STDOUT
	#
	# ------------------------------------------------------------------------------

	my $img_name = shift;
	my $img_dir = shift;
	my $img_alt = shift;
	my $img_align = shift;
	my $img_width = int shift;
	my $img_height = int shift;
	my $null = "";

	my $img_src = buildImage($img_name,$img_dir,$img_alt,$img_align,$img_width,$img_height);


	if ($img_src eq $null) {
		return 0;
	}
	
	print $img_src;

	return 1;
}

#----------------------------------------------------
sub buildImage {
	#
	# Build Image
	#
	# This will build img src code but with awareness of remote (http://) graphics.
	#
	# Parameters: ImageName[,Dir,ALT,Align,Width,Height]
	#
	# Optional:
	#	      Directory (uses $imagedir if not included)
	#	      Alt Tag
	#	      Alignment 
	#	      Width
	#	      Height
	#
	# Returns <img src string.
	#
	# ------------------------------------------------------------------------------

	my $img_name = shift;
	my $img_dir = shift;
	my $img_alt = shift;
	my $img_align = shift;
	my $img_width = int shift;
	my $img_height = int shift;

	my $img_src = $null;

	if (length($img_name) < 1) {
		return $img_src;
	}

	if (length($img_dir) < 1) {
		$img_dir = $imagedir;
	}

	if ($img_name =~ "http://") {
		$img_dir = "";
	}

	$img_src = "<img ";
	
	if (length($img_align) > 0) {
		$img_src .= "align=$img_align ";
	}

	$img_src .= "src=\"";

	if (length($img_dir) > 0) {
		$img_src .= "$img_dir/";
	}

	$img_src .= "$img_name";

	$img_src .= "\" ";

	if ($img_width > 0) {
		$img_src .= "width=$img_width ";
	}

	if ($img_height > 0) {
		$img_src .= "height=$img_height ";
	}

	if (length($img_alt) > 0) {
		$img_src .= "ALT=\"$img_alt\" ";
	}

	$img_src .= ">";

	return $img_src;
}

#---------------------------------------------------------------------------------------
sub fileExists {
	my $pathname = shift;
	my $retcode = 0;

	if (open(HANDLE, "$pathname")) {
		$retcode = 1;
	}else{
		$retcode = 0;
	}

	return $retcode;
	
}

#---------------------------------------------------------------------------------------
sub InitializeDisplay {
	# 
	# Display HTTP Header and Banner
	#
	#-------------------------------------------------------------------

	#-------------------------------------------------------------------
	# Set up some defaults just in case something bad happens
	#-------------------------------------------------------------------

	if ($color_background eq $null) {
			$color_background = "\#FFFFFF";
	}

	if ($color_text eq $null) {
			$color_text = "\#000000";
	}

	if ($color_visitedlink eq $null) {
			$color_visitedlink = "\#000040";
	}

	if ($color_activelink eq $null) {
			$color_activelink = "\#0000FF";
	}

	if ($color_link eq $null) {
			$color_link = "\#00009F";
	}

	if ($showpdaformat) {
		$size_title = "H5";
		$size_section = "H6";
		$size_subsection = "H4";
	}else{
		$size_title = "H2";
		$size_section = "H2";
		$size_subsection = "H3";
	}

	&ShowHTTPHeader;
	print "<HTML>\n<HEAD>\n";
	print "<meta http-equiv=\"Pragma\" content=\"no-cache\">\n";
	print "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">\n";
	if ((uc $program_module eq "MAIN") || (length($program_module) < 1)) {
		print "<TITLE>$program_title</TITLE>\n";
	}else{
		print "<TITLE>$program_title:$program_module</TITLE>\n";
	}
	print "</HEAD>\n<BODY bgcolor=$color_background text=$color_text vlink=$color_visitedlink alink=$color_activelink link=$color_link>\n";

	#-------------------------------------------------------------------------------------------
	# Prepare Titles
	#-------------------------------------------------------------------------------------------

	if ((uc $program_module eq "MAIN") || (length($program_module) < 1)) {
			$program_hdr = "<$size_title><font face=\"$font_title\">$program_title v$program_version (Build $program_build)</$size_title><$size_subsection>by $program_author</$size_subsection><p></font>\n";
		}else{
			$program_hdr = "<$size_title><font face=\"$font_title\">$program_title:$program_module v$program_version (Build $program_build)</$size_title><$size_subsection>by $program_author</$size_subsection><p></font>\n";
	}

	if (length($image_logo) > 0) {
		if ($showpdaformat) {
			showImage($image_logo);
		}else{
			showImage($image_logo);
		}
	}

	print $program_hdr;
	

}

1;
