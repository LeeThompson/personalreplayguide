#!/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
#
# DATABASE INFO
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

#------------------------------------------------------------------------------------
# About the only reason to edit this file now is to edit the listingmap or favorites
# lists.
#
# For database configuration you are better off editing prg.conf's [database] section
# or creating a database.conf.
#
#------------------------------------------------------------------------------------

use POSIX qw( strftime getcwd );

my $_version = "Personal ReplayGuide|Database Initialization Library|1|2|103|Lee Thompson";

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

require 'rg_config.pl';


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

#-------------------------------------------------------------------
# Define a mapping from IP address to xmltv or datadirect headend 
# listings.
#
# If specific replay units use other than the standard listings,
# define the specific mapping here.
# Separate multiple headends with the comma "," 
#-------------------------------------------------------------------
%listingmap = (
	"0.0.0.0",		"na.xml",
);


#-------------------------------------------------------------------
# Define the favorite channels lists
# Uncomment these lines and change the labels/channel lists
# to enable the favorite channels selection box
#-------------------------------------------------------------------
#%favorites = (
#	"Broadcast", "10,11,42,59,60",
#	"Movies", "550,551,575,576,533,534",
#);



#------------------------------------------------------------------------------------
sub InitDB{
	#
	# Load Database Configuration (getconfig does all the work)
	#
	#------------------------------------------------------------------------------------

	$db_driver = "SQLite";			# Database Type (ODBC,mysql,SQLite)
	$db_host = "localhost";			# Computer running SQL server
	$db_name = "tvlistings";		# Database Name
	$db_user = "username";			# Database User
	$db_pass = "password";			# Database Password
	
	$db_table_replayunits = "replayunits";	# Table for ReplayTV Units
	$db_table_channels = "channels";	# Table for Channel Information
	$db_table_tvlistings = "tvlistings";	# Table for Television Listings
	$db_table_schedule = "schedule";	# Table for Scheduled Recordings
	$db_table_castcrew = "castcrew";	# Table for Cast and Crew Data

	my $configfile = "database.conf";		# This is optional
	my $configstatus = getConfig($configfile);	# Read Configuration

		
	if (length($db_dsn_name) < 1) {
		$db_dsn_name = $db_name;
	}

	$db_conflict = 0;

	if (($db_table_replayunits eq $db_table_channels) || ($db_table_replayunits eq $db_table_tvlistings) || ($db_table_replayunits eq $db_table_schedule) || ($db_table_replayunits eq db_table_castcrew)) {
		$db_conflict = 1;
	}

	if (($db_table_channels eq $db_table_tvlistings) || ($db_table_channels eq $db_table_schedule) || ($db_table_channels eq db_table_castcrew)) {
		$db_conflict = 1;
	}

	if (($db_table_tvlistings eq $db_table_schedule) || ($db_table_tvlistings eq db_table_castcrew)) {
		$db_conflict = 1;
	}

	if ($db_table_schedule eq db_table_castcrew) {
		$db_conflict = 1;
	}

	return $configstatus;

	

}

1;

