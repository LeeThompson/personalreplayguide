#!/usr/bin/perl
#
# Personal ReplayGuide
# Configuration Library
# by Lee Thompson <thompsonl@logh.net>
# with bits by Philip Van Baren, Kanji T. Bates and Kevin J. Moye
#
# CONFIGURATION FUNCTIONS
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
#------------------------------------------------------------------------------------

my $_version = "Personal ReplayGuide|Configuration Function Library|1|0|26|Lee Thompson,Philip Van Baren,Kanji T. Bates,Kevin J. Moye";

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


#------------------------------------------------------------------------------------
# NOTE: Configuration Values are the only Global variables defined in this.
#------------------------------------------------------------------------------------
# Variables local to rg_config
#------------------------------------------------------------------------------------

my $configfile = "prg.conf";	# master configuration file
my $configpath = "";		# configuration path
my $s_replayguide = 0;		# look in replayguide
my $s_xmltv2sql = 0;		# look in xmltv2sql
my $s_datadirect = 0;		# look in datadirect
my $s_xmltv = 0;		# look in xmltv
my $s_datadirect2sql = 0;	# look in datadirect2sql
my $s_schd2sql = 0;		# look in schd2sql
my $s_database = 0;		# look in database
my $s_geticons = 0;		# look in geticons
my $s_global = 1;		# always read global section
my $s_global_priority = 1;	# set to 0 to allow sections to override globals
my $null = "";			# handy
my $do_downgrade_search = 1;	# downgrade to individual .conf files if section or
				# master file cannot be found.
my $allowinlinecomments_1 = 1;	# Allow inline comments (like this one)
my $allowinlinecomments_2 = 1;	# NOTE: The comment sequence cannot be doubled up! Like
my $allowinlinecomments_3 = 1;	# ## or it will not see it as a comment.   # Blah # is ok.
				#
				# If you need to, disable with allowinlinecomment_N to 0.
				#
				# allowinlinecomments_1 allows # inline comments 
				# allowinlinecomments_2 allows // inline comments
				# allowinlinecomments_3 allows ; inline comments
		
my $specialdebug = 0;		# special debug
my $option = "";		# init local	
my $parameter = "";		# init local
my $iscomment = 0;		# init local


if (length($ENV{PRG_CONFPATH}) > 0) {
	$configpath = $ENV{PRG_CONFPATH};
}


#------------------------------------------------------------------------------------
sub getConfig {
	#	Parameters: section to look for
	#		    ignore global (optional)
	#		    specific value (optional)
	#
	#	getConfig(Section)	eg. getConfig($configfile) will usually work
	#				    (the .conf suffix will be removed)
	#
	#	eg. getConfig("replayguide",1,"logfile") would load the log_pathname
	#	variable from the replayguide section.  Nothing else will be loaded or
 	# 	updated.
	#
	#				if the section is the same as the perl script
	#				minus the suffix you can also do
	#				getConfig($0)
	#
	#	Returns a bitmask	1		File Opened
	#				2		Globals Read
	#				4		Section Read as Requested
	#
	#				So a 7 is 'all successful'.
	#
	#----------------------------------------------------------------------------

	my $section = shift;		# look for this section
	my $noglobal = shift;		# No global
	my $specificvalue = shift;	# Specific Value

	my $specialdebug = 0;		# Special Debug Crap
	my $retcode = 0;		# return code

	if ($specialdebug ) { 
		print "getConfig::Starting\n";
		print "getConfig::parameters are section: \"$section\", noglobal: \"$noglobal\", specificvalue: \"$specificvalue\"\n";
	}

	if ($section eq $null) {
		if ($specialdebug ) { 
			print "getConfig::section is null, using calling script name ($script_pathname)\n";
		}

		$section = $script_pathname;
	}

	#-------------------------------------------------------------------
	# Determine What Section to Read
	#-------------------------------------------------------------------

	$sectionsearch = $section;
	
	if ($specialdebug ) { 
		print "getConfig::section: \"$section\", s_global: \"$s_global\"\n";
	}


	if ($specialdebug ) { 
		print "getConfig::checking \"$section\" for .conf\n";
	}

	if ($sectionsearch =~ /\.conf/ ) {
		($sectionsearch,$text) = split(/\.conf/, $section, 2);
		if ($specialdebug ) { 
			print "getConfig::split $sectionsearch,$text\n";
		}

	}

	if ($specialdebug ) { 
		print "getConfig::checking \"$section\" for .pl\n";
	}

	if ($sectionsearch =~ /\.pl/ ) {
		($sectionsearch,$text) = split(/\.pl/, $section, 2);
		if ($specialdebug ) { 
			print "getConfig::split $sectionsearch,$text\n";
		}
	}


	if ($specialdebug ) { 
		print "getConfig::checking \"$section\" for .exe\n";
	}

	if ($sectionsearch =~ /\.exe/ ) {
		($sectionsearch,$text) = split(/\.exe/, $section, 2);
		if ($specialdebug ) { 
			print "getConfig::split $sectionsearch,$text\n";
		}
	}

	if ($specialdebug ) { 
		print "getConfig::section search for \"$sectionsearch\"\n";
	}

	if (length($noglobal) > 0) {
		$s_global = 0;
		if ($specialdebug ) { 
			print "getConfig::global search is disabled\n";
		}
	}


	if (length($specificvalue) > 0) {
		$valuesearch = $specificvalue;
		if ($specialdebug ) { 
			print "getConfig::looking for specific value \"$valuesearch\"\n";
		}
	}

	#----------------------------------------------------
	# Make sure if the script name is passed in we look
	# for the right thing
	#----------------------------------------------------

	if ($specialdebug ) { 
		print "getConfig::translating script names to section names\n";
	}

	if (uc $sectionsearch eq 'GETCHANNELICONS') {
		$sectionsearch = "geticons";
	}
	if (uc $sectionsearch eq 'DATADIRECT_CLIENT') {
		$sectionsearch = "datadirect";
	}

	if (uc $sectionsearch eq 'SCHEDULE2SQL') {
		$sectionsearch = "SCHD2SQL";
	}

	if (uc $sectionsearch eq 'RG_INFO') {
		$sectionsearch = "DATABASE";
	}

	if ($specialdebug ) { 
		print "getConfig::$section->$sectionsearch\n";
	}

	if (uc $sectionsearch eq 'GLOBAL') {
		$sectionsearch = "";
		$s_global = 1;
		$do_downgrade_search = 0;
		if ($specialdebug ) { 
			print "getConfig::doing global only search.  global enabled, downgrade disabled, section nulled\n";
		}
	}



	#----------------------------------------------------
	# Raise Flags
	#----------------------------------------------------

	if ($specialdebug ) { 
		print "getConfig::raising flags\n";
	}

	if (uc $sectionsearch eq 'REPLAYGUIDE') {
		$s_replayguide = 1;
	}

	if (uc $sectionsearch eq 'XMLTV2SQL') {
		$s_xmltv2sql = 1;
	}


	if (uc $sectionsearch eq 'XMLTV') {
		$s_xmltv = 1;
	}

	if (uc $sectionsearch eq 'DATADIRECT') {
		$s_datadirect = 1;
	}

	if (uc $sectionsearch eq 'DATADIRECT2SQL') {
		$s_datadirect2sql = 1;
	}

	if (uc $sectionsearch eq 'SCHD2SQL') {
		$s_schd2sql = 1;
	}

	if (uc $sectionsearch eq 'DATABASE') {
		$s_database = 1;
	}

	if (uc $sectionsearch eq 'GETICONS') {
		$s_geticons = 1;
	}

	if ($specialdebug ) { 
		print "getConfig::section flags:\n";
		print "getConfig::   REPLAYGUIDE: $s_replayguide\n";
		print "getConfig::     XMLTV2SQL: $s_xmltv2sql\n";
		print "getConfig::         XMLTV: $s_xmltv\n";
		print "getConfig::    DATADIRECT: $s_datadirect\n";
		print "getConfig::DATADIRECT2SQL: $s_datadirect2sql\n";
		print "getConfig::      SCHD2SQL: $s_schd2sql\n";
		print "getConfig::      DATABASE: $s_database\n";
		print "getConfig::      GETICONS: $s_geticons\n";
		print "getConfig::        GLOBAL: $s_global_priority   Is Priority: $s_global_priority\n";
	}


	#-----------------------------------------------------------------------------
	# First try the global configuration
	#-----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "getConfig::Attempting to search for \"$sectionsearch\" within $configfile\n";
	}

	$retcode = &loadConfigFile($configfile,$null,$valuesearch);
	
	if ($specialdebug ) { 
		print "getConfig::loadConfigFile($configfile) returned $retcode\n";
	}


	#-----------------------------------------------------------------------------
	# Process Return Codes
	#-----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "getConfig::processing return codes for $configfile\n";
	}

	if ($retcode & 1) {
		if ($specialdebug ) { 
			print "getConfig::$configfile read successfully\n";
		}
	}else{
		if ($specialdebug ) { 
			print "getConfig::$configfile could not be opened or found\n";
		}
	}

	if ($retcode & 2) {
		if ($specialdebug ) { 
			print "getConfig::loaded values for global successfully\n";
		}
	}else{
		if ($specialdebug ) { 
			print "getConfig::failed to find values for global\n";
		}
	}

	if ($retcode & 4) {
		#-----------------------------------------------------------------------------
		# Succeeded to read the section we wanted
		#-----------------------------------------------------------------------------

		if ($specialdebug ) { 
			print "getConfig::loaded values for $sectionsearch successfully\n";
		}
	}else{
		if ($do_downgrade_search) {

			#-----------------------------------------------------------------------------
			# Try to load old config file
			#-----------------------------------------------------------------------------

			if ($specialdebug ) { 
				print "getConfig::Attempting to search within $sectionsearch.conf (downgrade)\n";
			}

			$retcode = &loadConfigFile("$sectionsearch.conf",$sectionsearch,$valuesearch);

			if ($specialdebug ) { 
				print "getConfig::loadConfigFile($sectionsearch.conf) returned $retcode\n";
			}

			#-----------------------------------------------------------------------------
			# Process Return Codes
			#-----------------------------------------------------------------------------

			if ($specialdebug ) { 
				print "getConfig::processing return codes for $sectionsearch.conf\n";
			}


			if ($retcode & 1) {
				if ($specialdebug ) { 
					print "getConfig::$sectionsearch.conf read successfully\n";
				}
			}else{
				if ($specialdebug ) { 
					print "getConfig::$sectionsearch.conf could not be opened or found\n";
				}
			}

			if ($retcode & 2) {
				if ($specialdebug ) { 
					print "getConfig::loaded values for global successfully\n";
				}
			}else{
				if ($specialdebug ) { 
					print "getConfig::failed to find values for global\n";
				}
			}

			if ($retcode & 4) {
				if ($specialdebug ) { 
					print "getConfig::loaded values for $sectionsearch successfully\n";
				}
			}else{
				if ($specialdebug ) { 
					print "getConfig::failed to find values for $sectionsearch\n";
				}
			}
		}else{
			if ($specialdebug ) { 
				print "getConfig::failed to find values for $sectionsearch (downgrade not permitted)\n";
			}
		}
	}

	if ($specialdebug ) { 
		print "getConfig::Exiting($retcode)\n";
	}


	return $retcode;

}


#------------------------------------------------------------------------------------
sub loadConfigFile($$$) {
	#
	# Process a Configuration File
	#
	#	Parameters: configuration file
	#		    section to force (optional)
	#
	# Returns the same bitmask as getConfig
	#
	#----------------------------------------------------------------------------

	#---------------------------------
	# Read File
	#---------------------------------

	my $configfile = shift;
	my $forcesection = shift;
	my $forceoption = shift;
	
	my $specialdebug = 0;
	my $comment = "";
	my $retcode = 0;
	my $currentsection = "";
	my $forced = 0;

	if ($specialdebug) {
		print "loadConfigFile::Start($configfile,$forcesection,$forceoption)\n";
	}

	#---------------------------------
	# If need be force a section
	#---------------------------------


	if (length($forcesection) > 0) {
		$currentsection = $forcesection;
		$currentsection = lc $currentsection;
		$forced = 1;
		if ($specialdebug) { 
			print "loadConfigFile::$configfile->Forcing Section: \"$currentsection\"\n";
		}

	}


	if ($specialdebug) { 
		print "loadConfigFile::Attempting to open $configfile for read\n";
	}

	if (open(CONFIGFILE, "<$configpath$configfile")) {
		while (<CONFIGFILE>) {
			chop $_;

			#---------------------------------
			# Ignore Comments
			#---------------------------------


			$iscomment = 0;

			if (substr($_,0,1) eq '#') {
				$iscomment = 1;
			}

			if (substr($_,0,1) eq ';') {
				$iscomment = 1;
			}
			
			if (substr($_,0,1) eq '/') {
				$iscomment = 1;
			}

			if ($_ eq $null) {
				$iscomment = 1;
			}

			#---------------------------------
			# We just started a section...
			#---------------------------------


			if (substr($_,0,1) eq '[') {
				$iscomment = 1;
				if (!$forced) {
					$_ = substr($_,1);
					($currentsection,$junk) = split(']', $_, 2);
					$currentsection = lc $currentsection;
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->Found Section \"$currentsection\"\n";
					}
				}
			}


			#---------------------------------
			# Get Option=Param
			#---------------------------------

			if ($iscomment) {
				$option = "";
				$parameter = "";
			}else{
        			($option,$parameter) = split('=', $_, 2);

				#-------------------------
				# Trim Whitespace
				#-------------------------

    				$option =~ s/^\s+//;
		    		$option =~ s/\s+$//;

				#-------------------------
				# Allow inline comments
				#-------------------------

	
				if ($allowinlinecomments_1) {
					$parameter =~ s/\s+#\s.*//;
				}

				if ($allowinlinecomments_2) {
					$parameter =~ s/\s+;\s.*//;
				}

				if ($allowinlinecomments_3) {
					$parameter =~ s/\s+\/\/\s.*//;
				}


				#-------------------------
				# Trim Whitespace
				#-------------------------

    				$parameter =~ s/^\s+//;
		    		$parameter =~ s/\s+$//;


				#---------------------------------
				# Looking for a specific option
				#---------------------------------
	
				if ((length($forceoption) > 0)) {
					if ((uc $option) ne (uc $forceoption)) {
						$iscomment = 1;
						if ($specialdebug) { 
							print "loadConfigFile::$configfile->no match ($option!=$forceoption)\n";
						}
					}else{
						if ($specialdebug) { 
							print "loadConfigFile::$configfile->match ($option==$forceoption)\n";
						}
					}
				}


			}

			#---------------------------------
			# Handle GLOBALs if they aren't
			# priority.
			#---------------------------------


			if (($currentsection eq "global") && ($s_global) && (!$s_global_priority)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadGlobalOptions($option)\n";
					}

					&loadGlobalOptions;
					$retcode = $retcode | 2;
				}
			}

			#---------------------------------
			# Handle replayguide.conf
			#---------------------------------

			if (($currentsection eq "replayguide") && ($s_replayguide)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadReplayGuideOptions($option)\n";
					}
					&loadReplayGuideOptions;
					$retcode = $$retcode | 4;
				}
			}
			#---------------------------------
			# Handle xmltv.conf
			#---------------------------------

			if (($currentsection eq "xmltv") && ($s_xmltv)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadXMLTVClientOptions($option)\n";
					}
					&loadXMLTVClientOptions;
					$retcode = $retcode | 4;
				}
			}


			#---------------------------------
			# Handle xmltv2sql.conf
			#---------------------------------

			if (($currentsection eq "xmltv2sql") && ($s_xmltv2sql)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadXMLTVToSQLOptions($option)\n";
					}
					&loadXMLTVToSQLOptions;
					$retcode = $retcode | 4;
				}
			}

			#---------------------------------
			# Handle datadirect.conf
			#---------------------------------

			if (($currentsection eq "datadirect") && ($s_datadirect)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadDataDirectOptions($option)\n";
					}
					&loadDataDirectOptions;
					$retcode = $retcode | 4;
				}
			}


			#---------------------------------
			# Handle datadirect2sql.conf
			#---------------------------------

			if (($currentsection eq "datadirect2sql") && ($s_datadirect2sql)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadDataDirectToSQLOptions($option)\n";
					}
					&loadDataDirectToSQLOptions;
					$retcode = $retcode | 4;
				}
			}


			#---------------------------------
			# Handle schd2sql.conf
			#---------------------------------

			if (($currentsection eq "schd2sql") && ($s_schd2sql)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadScheduleToSQLOptions($option)\n";
					}
					&loadScheduleToSQLOptions;
					$retcode = $retcode | 4;
				}
			}


			#---------------------------------
			# Handle database.conf
			#---------------------------------

			if (($currentsection eq "database") && ($s_database)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadDatabaseOptions($option)\n";
					}
					&loadDatabaseOptions;
					$retcode = $retcode | 4;
				}
			}

			#---------------------------------
			# Handle getchannelicons.conf
			#---------------------------------

			if (($currentsection eq "geticons") && ($s_geticons)) {
				if (!$iscomment) {
					if ($specialdebug) { 
						print "loadConfigFile::$configfile->loadGetChannelIconsOptions($option)\n";
					}
					&loadGetChannelIconsOptions;
					$retcode = $retcode | 4;
				}
			}


		}   
		close CONFIGFILE;
		$retcode = $retcode | 1;


		if ($specialdebug) { 
			print "loadConfigFile::$configfile->Closed\n";
		}

		if (($s_global_priority) && ($s_global) && (!$forced)) {
			if ($forced) {
				$currentsection = "global";
				if ($specialdebug) { 
					print "loadConfigFile::$configfile->Forced to $currentsection\n";
				}
			}else{
				$currentsection = "";
			}
			
			if (open(CONFIGFILE, "$configpath$configfile")) {
				if ($specialdebug) { 
					print "loadConfigFile::$configfile->Open (Reading)\n";
				}
	
				while (<CONFIGFILE>) {
					chop $_;

					#---------------------------------
					# Ignore Comments
					#---------------------------------

					$iscomment = 0;
	
					if (substr($_,0,1) eq '#') {
						$iscomment = 1;
					}

					if (substr($_,0,1) eq ';') {
						$iscomment = 1;
					}
			
					if (substr($_,0,1) eq '/') {
						$iscomment = 1;
					}

					if ($_ eq $null) {
						$iscomment = 1;
					}

					#---------------------------------
					# We just started a section...
					#---------------------------------


					if (substr($_,0,1) eq '[') {
						$iscomment = 1;
						if (!$forced) {
							$_ = substr($_,1);
							($currentsection,$junk) = split(']', $_, 2);
							$currentsection = lc $currentsection;
							if ($specialdebug) { 
								print "loadConfigFile::$configfile->Found Section \"$currentsection\"\n";
							}
						}
					}

					#---------------------------------
					# Get Option=Param
					#---------------------------------
	
					if ($iscomment) {
						$option = "";
						$parameter = "";
					}else{
        					($option,$parameter) = split('=', $_, 2);

						#-------------------------
						# Trim Whitespace
						#-------------------------

    						$option =~ s/^\s+//;
	    					$option =~ s/\s+$//;


						#-------------------------
						# Allow inline comments
						#-------------------------
	
						if ($allowinlinecomments_1) {
							$parameter =~ s/\s+#\s.*//;
						}
	
						if ($allowinlinecomments_2) {
							$parameter =~ s/\s+;\s.*//;
						}

						if ($allowinlinecomments_3) {
							$parameter =~ s/\s+\/\/\s.*//;
						}
	


						#-------------------------
						# Trim Whitespace
						#-------------------------


    						$parameter =~ s/^\s+//;
	    					$parameter =~ s/\s+$//;

						#---------------------------------
						# Looking for a specific option
						#---------------------------------
		
						if ((length($forceoption) > 0)) {
							if ((uc $option) ne (uc $forceoption)) {
								$iscomment = 1;
								if ($specialdebug) { 
									print "loadConfigFile::$configfile->no match ($forceoption!=$option)\n";
								}
							}else{
								if ($specialdebug) { 
									print "loadConfigFile::$configfile->match ($forceoption==$option)\n";
								}
							}
						}
	
					}

	

					#---------------------------------
					# Handle GLOBAL if they take
					# priority over locals.
					#---------------------------------

					if (($currentsection eq "global") && ($s_global) && ($s_global_priority)) {
						if (!$iscomment) {
							if ($specialdebug) { 
								print "loadConfigFile::$configfile->loadGlobalOptions->Priority->($option)\n";
							}
							&loadGlobalOptions;
							$retcode = $retcode | 2;
						}else{
							if (length($forceoption) > 0) {
								$retcode = $retcode | 2;
							}
						}
					}


				}
			}
			close CONFIGFILE;
			$retcode = $retcode | 1;


			if ($specialdebug) { 
				print "loadConfigFile::$configfile->Closed\n";
			}


		}

	}else{
		if ($specialdebug) { 
			print "loadConfigFile::$configfile->Failed\n";
		}

	}

	#---------------------------------
	# All done, return status.
	#---------------------------------

	if ($specialdebug) { 
		print "loadConfigFile::Exiting($retcode)\n";
	}

	return $retcode;

}


#------------------------------------------------------------------------------------
sub loadFile($$) {
	#
	# Load a file into an array.
	#
	#	Parameters: file to load
	#
	# Returns array,elementcount
	#
	#----------------------------------------------------------------------------

	#---------------------------------
	# Read File
	#---------------------------------

	my $filename = shift;
	my $nocomments = int shift;

	my $dataline = "";
	my $specialdebug = 0;
	my $dataarray = "";
	my $comment = "";
	my $ctr = 0;

	if ($specialdebug) {
		print "loadFile::Start($filename,$nocomments)\n";
	}

	if ($nocomments) {
		$allowinlinecomments_1 = 0;
		$allowinlinecomments_2 = 0;
		$allowinlinecomments_3 = 0;
	}


	if ($specialdebug) { 
		print "loadFile::Attempting to open $filename for read\n";
	}

	if (open(FHANDLE, $filename)) {
		while (<FHANDLE>) {
			chop $_;
			$dataline = $_;

			#---------------------------------
			# Ignore Comments
			#---------------------------------


			$iscomment = 0;

			if (!$nocomments) {		
				if (substr($dataline,0,1) eq '#') {
					$iscomment = 1;
				}

				if (substr($dataline,0,1) eq ';') {
					$iscomment = 1;
				}
			
				if (substr($dataline,0,1) eq '/') {
					$iscomment = 1;
				}
			}

			if ($dataline eq $null) {
				$iscomment = 1;
			}


			if ($iscomment) {
				$dataline = "";
			}else{



				#-------------------------
				# Allow inline comments
				#-------------------------
	
				if ($allowinlinecomments_1) {
					if ($dataline =~ /\#/ ) {
						($dataline,$comment) = split(/\#/, $dataline, 2);
					}
				}

				if ($allowinlinecomments_2) {
					if ($dataline =~ /;/ ) {
						($dataline,$comment) = split(/;/, $dataline, 2);
					}
				}

				if ($allowinlinecomments_3) {
					if ($dataline =~ /\/\// ) {
						($dataline,$comment) = split(/\/\//, $dataline, 2);
					}
				}

				#-------------------------
				# Trim Whitespace
				#-------------------------

    				$dataline =~ s/^\s+//;
		    		$dataline =~ s/\s+$//;

				$ctr++;
				$dataarray[$ctr] = $dataline;
			}
		}

		close FHANDLE;
	}else{
		return;
	}
	

	return @dataarray;
}
	


#------------------------------------------------------------------------------------
sub loadGlobalOptions{
	# 
	# Load values for Personal ReplayGuide
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadGlobalOptions::starting\n";
	}

	if (uc $option eq "VERBOSE") {
		$verbose = $parameter;
	}

	if (uc $option eq "DEBUG") {
		$debug = $parameter;
	}

	if (uc $option eq "DATAFEED") {
		$datafeed = $parameter;
	}

	if (uc $option eq "ALLOW") {
		$allow_list = $parameter;
	}

	if (uc $option eq "PDA") {
		$pda_list = $parameter;
	}

	if (uc $option eq "LOGFILE") {
		$log_pathname = $parameter;
	}

	if (uc $option eq "LOGMODULENAME") {
		$log_module_name = $parameter;
	}

	if (uc $option eq "SCHEDULER") {
		$scheduler  = $parameter;
	}

	if (uc $option eq "SCHEDULE2SQL") {
		$schedule2sql  = $parameter;
	}

	if (uc $option eq "IMAGE_LOGO") {
		$image_logo = $parameter;
	}

	if (uc $option eq "IMAGEDIR") {
		$imagedir = $parameter;
	}

	if (uc $option eq "WWWDIR") {
		$wwwdir  = $parameter;
	}

	if (uc $option eq "SCRIPTDIR") {
		$scriptdir  = $parameter;
	}

	if (uc $option eq "SCRIPTNAME") {
		$scriptname  = $parameter;
	}

	if (uc $option eq "SCHEDULENAME") {
		$schedulename  = $parameter;
	}

	if (uc $option eq "XMLFILE") {
		$cnf_xmlfile = $parameter;
	}

	if (uc $option eq "BACKGROUNDCOLOR") {
		$color_background = $parameter;
	}
	
	if (uc $option eq "TEXTCOLOR") {
		$color_text = $parameter;
	}
	
	if (uc $option eq "VISITEDLINKCOLOR") {
		$color_visitedlink = $parameter;
	}

	if (uc $option eq "ACTIVELINKCOLOR") {
		$color_activelink = $parameter;
	}

	if (uc $option eq "LINKCOLOR") {
		$color_link = $parameter;
	}

	if (uc $option eq "HEADINGBACKGROUNDCOLOR") {
		$color_headingbackground = $parameter;
	}

	if (uc $option eq "HEADINGTEXTCOLOR") {
		$color_headingtext = $parameter;
	}
		
	if (uc $option eq "TITLEFONT") {
		$font_title = $parameter;
	}
	
	if (uc $option eq "MENUFONT") {
		$font_menu = $parameter;
	}

	if ((uc $option eq "USINGAPACHE") || (uc $option eq "SUPRESSHTTPHEADER")) {
		$supresshttpheader = $parameter;
	}

	if (uc $option eq "SUPRESSCONTENTTYPE") {
		$supresscontenttype = $parameter;
	}

	if (uc $option eq "ALLOWSQLSUBSTITUTIONS") {
		$allow_sql_substitutions = $parameter;
	}

	
	if ($specialdebug ) { 
		print "loadGlobalOptions::exiting\n";
	}

	return 1;
}


#------------------------------------------------------------------------------------
sub loadDatabaseOptions{
	# 
	# Load values for rg_info.pl
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadDatabaseOptions::starting\n";
	}

	if (uc $option eq "DRIVER") {
		$db_driver = $parameter;
	}

	if (uc $option eq "USERNAME") {
		$db_user = $parameter;
	}

	if (uc $option eq "PASSWORD") {
		$db_pass = $parameter;
	}

	if (uc $option eq "HOST") {
		$db_host = $parameter;
	}

	if (uc $option eq "DATABASE") {
		$db_name = $parameter;
	}

	if (uc $option eq "DSN") {
		$db_dsn_name = $parameter;
	}

	if (uc $option eq "TABLE_REPLAYUNITS") {
		$db_table_replayunits = $parameter;
	}

	if (uc $option eq "TABLE_CHANNELS") {
		$db_table_channels = $parameter;
	}

	if (uc $option eq "TABLE_TVLISTINGS") {
		$db_table_tvlistings = $parameter;
	}

	if (uc $option eq "TABLE_SCHEDULE") {
		$db_table_schedule = $parameter;
	}

	if (uc $option eq "TABLE_CASTCREW") {
		$db_table_castcrew= $parameter;
	}

	if ($specialdebug ) { 
		print "loadDatabaseOptions::exiting\n";
	}

	return 1;
}

#------------------------------------------------------------------------------------
sub loadScheduleToSQLOptions{
	# 
	# Load values for schd2sql.pl
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadScheduleToSQLOptions::starting\n";
	}


	if (uc $option eq "XMLFILE") {
		$cnf_xmlfile = $parameter;
	}

	if (uc $option eq "DATAFEED") {
		$datafeed = $parameter;
	}

	if (uc $option eq "DEBUG") {
		$debug = $parameter;
	}

	if (uc $option eq "LOGFILE") {
		$log_pathname = $parameter;
	}

	if (uc $option eq "LOGMODULENAME") {
		$log_module_name = $parameter;
	}

	if (uc $option eq "REPLAYSCHEDULE") {
		$replaySchedule = $parameter;
	}

	if (uc $option eq "DO_NOT_INSERT") {
		$do_not_insert = $parameter;
	}

	if (uc $option eq "DO_NOT_DROP_ROWS") {
		$do_not_drop_rows = $parameter;
	}

	if (uc $option eq "ALLOW") {
		$allow_list = $parameter;
	}

	if (uc $option eq "VERBOSE") {
		$verbose = $parameter;
	}

	if (uc $option eq "BACKGROUNDCOLOR") {
		$color_background = $parameter;
	}
	
	if (uc $option eq "TEXTCOLOR") {
		$color_text = $parameter;
	}
	
	if (uc $option eq "VISITEDLINKCOLOR") {
		$color_visitedlink = $parameter;
	}

	if (uc $option eq "ACTIVELINKCOLOR") {
		$color_activelink = $parameter;
	}

	if (uc $option eq "LINKCOLOR") {
		$color_link = $parameter;
	}

	if (uc $option eq "HEADINGBACKGROUNDCOLOR") {
		$color_headingbackground = $parameter;
	}

	if (uc $option eq "HEADINGTEXTCOLOR") {
		$color_headingtext = $parameter;
	}
		
	if (uc $option eq "TITLEFONT") {
		$font_title = $parameter;
	}
	
	if (uc $option eq "MENUFONT") {
		$font_menu = $parameter;
	}


	if ($specialdebug ) { 
		print "loadScheduleToSQLOptions::exiting\n";
	}
	
	return 1;
}

#------------------------------------------------------------------------------------
sub loadDataDirectToSQLOptions{
	# 
	# Load values for datadirect2sql.pl
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadDataDirectToSQLOptions::starting\n";
	}


	if (uc $option eq "XMLFILE") {
		$cnf_xmlfile = $parameter;
	}

	if (uc $option eq "MULTIPLIER") {
		$multiplier = $parameter;
	}

	if (uc $option eq "DEBUG") {
		$debug = $parameter;
	}

	if (uc $option eq "DOTINTERVAL") {
		$dotinterval = $parameter;
	}

	if (uc $option eq "TITLEMAP") {
		$cnf_titlemap = $parameter;
	}

	if (uc $option eq "CHANNELMAP") {
		$cnf_channelmap = $parameter;
	}

	if (uc $option eq "MAXROWS") {
		$maxrows = $parameter;
	}

	if (uc $option eq "DO_NOT_INSERT") {
		$do_not_insert = $parameter;
	}

	if (uc $option eq "DO_NOT_DROP_ROWS") {
		$do_not_drop_rows = $parameter;
	}

	if (uc $option eq "USE_CASTCREW") {
		$use_castcrew = $parameter;
	}

	if (uc $option eq "ALLOW") {
		$allow_list = $parameter;
	}

	if (uc $option eq "VERBOSE") {
		$verbose = $parameter;
	}

	if (uc $option eq "BACKGROUNDCOLOR") {
		$color_background = $parameter;
	}
	
	if (uc $option eq "TEXTCOLOR") {
		$color_text = $parameter;
	}
	
	if (uc $option eq "VISITEDLINKCOLOR") {
		$color_visitedlink = $parameter;
	}

	if (uc $option eq "ACTIVELINKCOLOR") {
		$color_activelink = $parameter;
	}

	if (uc $option eq "LINKCOLOR") {
		$color_link = $parameter;
	}

	if (uc $option eq "HEADINGBACKGROUNDCOLOR") {
		$color_headingbackground = $parameter;
	}

	if (uc $option eq "HEADINGTEXTCOLOR") {
		$color_headingtext = $parameter;
	}
		
	if (uc $option eq "TITLEFONT") {
		$font_title = $parameter;
	}
	
	if (uc $option eq "MENUFONT") {
		$font_menu = $parameter;
	}

	if (uc $option eq "LOGFILE") {
		$log_pathname = $parameter;
	}

	if (uc $option eq "LOGMODULENAME") {
		$log_module_name = $parameter;
	}

	if (uc $option eq "SHOWEPISODENUMBER") {
		$show_episode_number = $parameter;
	}

	if (uc $option eq "SHOWFIRSTAIREDDATE") {
		$show_first_aired_date = $parameter;
	}
	if ($specialdebug ) { 
		print "loadDataDirectToSQLOptions::exiting\n";
	}

	return 1;

}


#------------------------------------------------------------------------------------
sub loadDataDirectOptions{
	# 
	# Load values for datadirect_client.pl
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadDataDirectOptions::starting\n";
	}


	if (uc $option eq "SUCCESSCODE") {
		$datafeed_success= $parameter;
	}

	if (uc $option eq "CLIENT") {
		$datafeed_client = $parameter;
	}

	if (uc $option eq "CONVERTER") {
		$datafeed_converter = $parameter;
	}

	if (uc $option eq "PARAMETERS") {
		$datafeed_parameters = $parameter;
	}

	if (uc $option eq "REDIRECTOUTPUT") {
		$datafeed_redirectoutput = $parameter;
	}

	if (uc $option eq "GETICONS") {
		$datafeed_geticons = $parameter;
	}

	if (uc $option eq "GETICONSCRIPT") {
		$datafeed_geticonscript = $parameter;
	}

	if (uc $option eq "XMLFILE") {
		$cnf_xmlfile = $parameter;
	}

	if (uc $option eq "WEBSERVICE") {
		$webservice = $parameter;
	}	

	if (uc $option eq "USERNAME") {
		$username = $parameter;
	}

	if (uc $option eq "PASSWORD") {
		$password = $parameter;
	}
	
	if (uc $option eq "DAYS") {
		$days = $parameter;
	}

	if (uc $option eq "DEBUG") {
		$debug = $parameter;
	}

	if (uc $option eq "VERBOSE") {
		$verbose = $parameter;
	}

	if (uc $option eq "ALLOW") {
		$allow_list = $parameter;
	}

	if (uc $option eq "BACKGROUNDCOLOR") {
		$color_background = $parameter;
	}
	
	if (uc $option eq "TEXTCOLOR") {
		$color_text = $parameter;
	}
	
	if (uc $option eq "VISITEDLINKCOLOR") {
		$color_visitedlink = $parameter;
	}

	if (uc $option eq "ACTIVELINKCOLOR") {
		$color_activelink = $parameter;
	}

	if (uc $option eq "LINKCOLOR") {
		$color_link = $parameter;
	}

	if (uc $option eq "HEADINGBACKGROUNDCOLOR") {
		$color_headingbackground = $parameter;
	}

	if (uc $option eq "HEADINGTEXTCOLOR") {
		$color_headingtext = $parameter;
	}
		
	if (uc $option eq "TITLEFONT") {
		$font_title = $parameter;
	}
	
	if (uc $option eq "MENUFONT") {
		$font_menu = $parameter;
	}

	if (uc $option eq "LOGFILE") {
		$log_pathname = $parameter;
	}

	if (uc $option eq "LOGMODULENAME") {
		$log_module_name = $parameter;
	}


	if ($specialdebug ) { 
		print "loadDataDirectOptions::exiting\n";
	}

	return 1;
}




#------------------------------------------------------------------------------------
sub loadXMLTVClientOptions{
	# 
	# Load values for xmltv
	#
	#----------------------------------------------------------------------------


	if ($specialdebug ) { 
		print "loadXMLTVClientOptions::starting\n";
	}

	if (uc $option eq "SUCCESSCODE") {
		$datafeed_success= $parameter;
	}

	if (uc $option eq "CLIENT") {
		$datafeed_client = $parameter;
	}

	if (uc $option eq "CONVERTER") {
		$datafeed_converter = $parameter;
	}

	if (uc $option eq "PARAMETERS") {
		$datafeed_parameters = $parameter;
	}

	if (uc $option eq "REDIRECTOUTPUT") {
		$datafeed_redirectoutput = $parameter;
	}

	if (uc $option eq "GETICONS") {
		$datafeed_geticons = $parameter;
	}

	if (uc $option eq "GETICONSCRIPT") {
		$datafeed_geticonscript = $parameter;
	}


	if ($specialdebug ) { 
		print "loadXMLTVClientOptions::exiting\n";
	}

	return 1;

}


#------------------------------------------------------------------------------------
sub loadXMLTVToSQLOptions{
	# 
	# Load values for xmltv2sql.pl
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadXMLTVToSQLOptions::starting\n";
	}

	if (uc $option eq "XMLFILE") {
		$cnf_xmltv = $parameter;
	}

	if (uc $option eq "POSTALCODE") {
		$postalcode = $parameter;
	}

	if (uc $option eq "LINEUPNAME") {
		$lineupname = $parameter;
	}

	if (uc $option eq "SYSTEMTYPE") {
		$systemtype = $parameter;
	}

	if (uc $option eq "MULTIPLIER") {
		$multiplier = $parameter;
	}

	if (uc $option eq "DEBUG") {
		$debug = $parameter;
	}

	if (uc $option eq "DOTINTERVAL") {
		$dotinterval = $parameter;
	}
	
	if (uc $option eq "TITLEMAP") {
		$cnf_titlemap = $parameter;
	}

	if (uc $option eq "CHANNELMAP") {
		$cnf_channelmap = $parameter;
	}

	if (uc $option eq "MAXROWS") {
		$maxrows = $parameter;
	}

	if (uc $option eq "DO_NOT_INSERT") {
		$do_not_insert = $parameter;
	}

	if (uc $option eq "DO_NOT_DROP_ROWS") {
		$do_not_drop_rows = $parameter;
	}

	if (uc $option eq "LOGFILE") {
		$log_pathname = $parameter;
	}

	if (uc $option eq "LOGMODULENAME") {
		$log_module_name = $parameter;
	}

	if (uc $option eq "ALLOW") {
		$allow_list = $parameter;
	}

	if (uc $option eq "VERBOSE") {
		$verbose = $parameter;
	}

	if (uc $option eq "BACKGROUNDCOLOR") {
		$color_background = $parameter;
	}
	
	if (uc $option eq "TEXTCOLOR") {
		$color_text = $parameter;
	}
	
	if (uc $option eq "VISITEDLINKCOLOR") {
		$color_visitedlink = $parameter;
	}

	if (uc $option eq "ACTIVELINKCOLOR") {
		$color_activelink = $parameter;
	}

	if (uc $option eq "LINKCOLOR") {
		$color_link = $parameter;
	}

	if (uc $option eq "HEADINGBACKGROUNDCOLOR") {
		$color_headingbackground = $parameter;
	}

	if (uc $option eq "HEADINGTEXTCOLOR") {
		$color_headingtext = $parameter;
	}
		
	if (uc $option eq "TITLEFONT") {
		$font_title = $parameter;
	}
	
	if (uc $option eq "MENUFONT") {
		$font_menu = $parameter;
	}

	if ($specialdebug ) { 
		print "loadXMLTVToSQLOptions::exiting\n";
	}

	return 1;

}


#------------------------------------------------------------------------------------
sub loadGetChannelIconsOptions{
	# 
	# Load values for getchannelicons.pl
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadGetChannelIconsOptions::starting\n";
	}

	if (uc $option eq "PROVIDERID") {
		$providerid = $parameter;
	}

	if (uc $option eq "ZIPCODE") {
		$zipcode = $parameter;
	}

	if (uc $option eq "CHANNELICONDIR") {
		$channelicondir = $parameter;
	}

	if (uc $option eq "DEBUG") {
		$debug = $parameter;
	}

	if (uc $option eq "VERBOSE") {
		$verbose = $parameter;
	}

	if ($specialdebug ) { 
		print "loadGetChannelIconsOptions::exiting\n";
	}

	return 1;

}

#------------------------------------------------------------------------------------
sub loadReplayGuideOptions{
	# 
	# Load values for replayguide.pl
	#
	#----------------------------------------------------------------------------

	if ($specialdebug ) { 
		print "loadReplayGuideOptions::starting\n";
	}

	if (uc $option eq "DEFAULTSLOT") {
		$defaultshowslots  = $parameter;
	}

	if (uc $option eq "DEFAULTSHOWHOURS") {
		$defaultshowhours = $parameter;
	}

	if (uc $option eq "ALLOW") {
		$allow_list = $parameter;
	}

	if (uc $option eq "PDA") {
		$pda_list = $parameter;
	}

	if (uc $option eq "DEBUG") {
		$debug  = $parameter;
	}

	if (uc $option eq "WWWDIR") {
		$wwwdir  = $parameter;
	}

	if (uc $option eq "SCRIPTDIR") {
		$scriptdir  = $parameter;
	}

	if (uc $option eq "SCRIPTNAME") {
		$scriptname  = $parameter;
	}

	if (uc $option eq "IMAGEDIR") {
		$imagedir = $parameter;
	}

	if (uc $option eq "SCHEDULENAME") {
		$schedulename  = $parameter;
	}

	if (uc $option eq "SCHEDULER") {
		$scheduler  = $parameter;
	}

	if (uc $option eq "SCHEDULE2SQL") {
		$schedule2sql  = $parameter;
	}

	if (uc $option eq "NEWWINDOW") {
		$newwindow  = $parameter;
	}

	if (uc $option eq "SHOWCHANNELICONS") {
		$showchannelicons = $parameter;
	}
		
	if (uc $option eq "CHANNELICONDIR") {
		$channelicondir = $parameter;
	}

	if (uc $option eq "SHOWRTVICONS") {
		$showrtvicons = $parameter;
	}

	if (uc $option eq "SHOWRTVTHEMES") {
		$showrtvthemes = $parameter;
	}

	if (uc $option eq "SHOWHEADERROWS") {
		$showheaderrows = $parameter;
	}

	if (uc $option eq "SHOWBUTTONICONS") {
		$showbuttonicons = $parameter;
	}

	if (uc $option eq "DEFAULTREPLAYTV") {
		$defaultreplaytv = $parameter;
	}

	if (uc $option eq "IMAGE_BPGR") {
		$image_bpgr = $parameter;
	}

	if (uc $option eq "IMAGE_CBPGR") {
		$image_cbpgr = $parameter;
	}

	if (uc $option eq "IMAGE_LOGO") {
		$image_logo = $parameter;
	}

	if (uc $option eq "IMAGE_APGR") {
		$image_apgr = $parameter;
	}	

	if (uc $option eq "IMAGE_CAPGR") {
		$image_capgr = $parameter;
	}

	if (uc $option eq "IMAGE_PPGR") {
		$image_ppgr = $parameter;
	}

	if (uc $option eq "IMAGE_CPPGR") {
		$image_cppgr = $parameter;
	}

	if (uc $option eq "IMAGE_GR") {
		$image_gr = $parameter;
	}

	if (uc $option eq "IMAGE_CGR") {
		$image_cgr = $parameter;
	}

	if (uc $option eq "IMAGE_R") {
		$image_r = $parameter;
	}

	if (uc $option eq "IMAGE_CR") {
		$image_cr = $parameter;
	}

	if (uc $option eq "IMAGE_BPR") {
		$image_bpr = $parameter;
	}

	if (uc $option eq "IMAGE_CBPR") {
		$image_cbpr = $parameter;
	}

	if (uc $option eq "IMAGE_APR") {
		$image_apr = $parameter;
	}

	if (uc $option eq "IMAGE_CAPR") {
		$image_capr = $parameter;
	}

	if (uc $option eq "IMAGE_PPR") {
		$image_ppr = $parameter;
	}

	if (uc $option eq "IMAGE_CPPR") {
		$image_cppr = $parameter;
	}

	if (uc $option eq "IMAGE_GS") {
		$image_gs = $parameter;
	}

	if (uc $option eq "IMAGE_CGS") {
		$image_cgs = $parameter;
	}

	if (uc $option eq "IMAGE_S") {
		$image_s = $parameter;
	}

	if (uc $option eq "IMAGE_CS") {
		$image_cs = $parameter;
	}

	if (uc $option eq "IMAGE_BPGS") {
		$image_bpgs = $parameter;
	}

	if (uc $option eq "IMAGE_CBPGS") {
		$image_cbpgs = $parameter;
	}

	if (uc $option eq "IMAGE_APGS") {
		$image_apgs = $parameter;
	}

	if (uc $option eq "IMAGE_CAPGS") {
		$image_capgs = $parameter;
	}

	if (uc $option eq "IMAGE_PPGS") {
		$image_ppgs = $parameter;
	}

	if (uc $option eq "IMAGE_CPPGS") {
		$image_cppgs = $parameter;
	}

	if (uc $option eq "IMAGE_BPS") {
		$image_bps = $parameter;
	}

	if (uc $option eq "IMAGE_CBPS") {
		$image_cbps = $parameter;
	}

	if (uc $option eq "IMAGE_APS") {
		$image_aps = $parameter;
	}

	if (uc $option eq "IMAGE_CAPS") {
		$image_caps = $parameter;
	}
	
	if (uc $option eq "IMAGE_PPS") {
		$image_pps = $parameter;
	}

	if (uc $option eq "IMAGE_CPPS") {
		$image_cpps = $parameter;
	}

	if (uc $option eq "IMAGE_TW") {
		$image_tw = $parameter;
	}

	if (uc $option eq "IMAGE_TL") {
		$image_tl = $parameter;
	}

	if (uc $option eq "IMAGE_GT") {
		$image_gt = $parameter;
	}
	
	if (uc $option eq "IMAGE_CGT") {
		$image_cgt = $parameter;
	}

	if (uc $option eq "REFRESHINTERVAL") {
		$defaultrefreshinterval = $parameter;
	}

	if (uc $option eq "SNAPSHOTPATH") {
		$rtv_snapshotpath = $parameter;
	}
	
	if (uc $option eq "SEARCHFUTUREONLY") {
		$searchfutureonly = $parameter;
	}

	if (uc $option eq "TODOOPTION") {
		$todooption = $parameter;
	}

	if (uc $option eq "TODOFROMSTART") {
		$todofromstart = $parameter;
	}

	if (uc $option eq "LOGFILE") {
		$log_pathname = $parameter;
	}

	if (uc $option eq "LOGMODULENAME") {
		$log_module_name = $parameter;
	}

	if (uc $option eq "FUTURESHOWCOLOR") {
		$color_show[2] = $parameter;
	}

	if (uc $option eq "CURRENTSHOWCOLOR") {
		$color_show[1] = $parameter;
	}

	if (uc $option eq "PASTSHOWCOLOR") {
		$color_show[0] = $parameter;
	}

	if (uc $option eq "FUTURESCHEDULEDCOLOR") {
		$color_scheduled[2] = $parameter;
	}

	if (uc $option eq "CURRENTSCHEDULEDCOLOR") {
		$color_scheduled[1] = $parameter;
	}

	if (uc $option eq "PASTSCHEDULEDCOLOR") {
		$color_scheduled[0] = $parameter;
	}

	if (uc $option eq "FUTURECONFLICTCOLOR") {
		$color_conflict[2] = $parameter;
	}

	if (uc $option eq "CURRENTCONFLICTCOLOR") {
		$color_conflict[1] = $parameter;
	}

	if (uc $option eq "PASTCONFLICTCOLOR") {
		$color_conflict[0] = $parameter;
	}

	if (uc $option eq "FUTURETHEMECOLOR") {
		$color_theme[2] = $parameter;
	}

	if (uc $option eq "CURRENTTHEMECOLOR") {
		$color_theme[1] = $parameter;
	}

	if (uc $option eq "PASTTHEMECOLOR") {
		$color_theme[0] = $parameter;
	}

	if (uc $option eq "FUTURETHEMECONFLICTCOLOR") {
		$color_theme_conflict[2] = $parameter;
	}

	if (uc $option eq "CURRENTTHEMECONFLICTCOLOR") {
		$color_theme_conflict[1] = $parameter;
	}

	if (uc $option eq "PASTTHEMECONFLICTCOLOR") {
		$color_theme_conflict[0] = $parameter;
	}

	if (uc $option eq "BACKGROUNDCOLOR") {
		$color_background = $parameter;
	}
	
	if (uc $option eq "TEXTCOLOR") {
		$color_text = $parameter;
	}
	
	if (uc $option eq "VISITEDLINKCOLOR") {
		$color_visitedlink = $parameter;
	}

	if (uc $option eq "ACTIVELINKCOLOR") {
		$color_activelink = $parameter;
	}

	if (uc $option eq "LINKCOLOR") {
		$color_link = $parameter;
	}

	if (uc $option eq "CHANNELBACKGROUNDCOLOR") {
		$color_channelbackground = $parameter;
	}

	if (uc $option eq "CHANNELTEXTCOLOR") {
		$color_channeltext = $parameter;
	}

	if (uc $option eq "HEADINGBACKGROUNDCOLOR") {
		$color_headingbackground = $parameter;
	}

	if (uc $option eq "HEADINGTEXTCOLOR") {
		$color_headingtext = $parameter;
	}
		
	if (uc $option eq "TITLEFONT") {
		$font_title = $parameter;
	}
	
	if (uc $option eq "MENUFONT") {
		$font_menu = $parameter;
	}
	
	if (uc $option eq "LISTINGSFONT") {
		$font_listings = $parameter;
	}
	
	if (uc $option eq "DETAILFONT") {
		$font_detail = $parameter;
	}
	
	if (uc $option eq "CHANNELFONT") {
		$font_channel = $parameter;
	}

	if (uc $option eq "HEADINGFONT") {
		$font_heading = $parameter;
	}

	if (uc $option eq "CONFIRMICON") {
		$icon_confirm = $parameter;
	}

	if (uc $option eq "LOCATEICON") {
		$icon_locate = $parameter;
	}

	if (uc $option eq "NOWICON") {
		$icon_now = $parameter;
	}

#	if (uc $option eq "REFRESHICON") {
#		$icon_refresh = $parameter;
#	}

	if (uc $option eq "GOICON") {
		$icon_go = $parameter;
	}

	if (uc $option eq "ALLICON") {
		$icon_all = $parameter;
	}

	if (uc $option eq "FINDALLICON") {
		$icon_findall = $parameter;
	}

	if (uc $option eq "PREVWINDOWICON") {
		$icon_prevwindow = $parameter;
	}

	if (uc $option eq "NEXTWINDOWICON") {
		$icon_nextwindow = $parameter;
	}

	if (uc $option eq "PREVCHANICON") {
		$icon_prevchan = $parameter;
	}

	if (uc $option eq "NEXTCHANICON") {
		$icon_nextchan = $parameter;
	}

	if (uc $option eq "FINDICON") {
		$icon_find = $parameter;
	}

	if (uc $option eq "SELECTICON") {
		$icon_select = $parameter;
	}

	if (uc $option eq "SCHEDULEICON") {
		$icon_schedule = $parameter;
	}

	if (uc $option eq "DONEICON") {
		$icon_done = $parameter;
	}

	if (uc $option eq "PRIMEICON") {
		$icon_tonight = $parameter;
	}

	if (uc $option eq "IMAGE_STEREO") {
		$image_stereo = $parameter;
	}

	if (uc $option eq "IMAGE_REPEAT") {
		$image_repeat = $parameter;
	}

	if (uc $option eq "IMAGE_CC") {
		$image_cc = $parameter;
	}

	if (uc $option eq "IMAGE_TVG") {
		$image_tvg = $parameter;
	}

	if (uc $option eq "IMAGE_TVPG") {
		$image_tvpg = $parameter;
	}

	if (uc $option eq "IMAGE_TV14") {
		$image_tv14 = $parameter;
	}

	if (uc $option eq "IMAGE_TVMA") {
		$image_tvma = $parameter;
	}

	if (uc $option eq "IMAGE_TVY") {
		$image_tvy = $parameter;
	}

	if (uc $option eq "IMAGE_TVY7") {
		$image_tvy7 = $parameter;
	}

	if (uc $option eq "IMAGE_MPAAG") {
		$image_mpaag = $parameter;
	}

	if (uc $option eq "IMAGE_MPAAPG") {
		$image_mpaapg = $parameter;
	}

	if (uc $option eq "IMAGE_MPAAPG13") {
		$image_mpaapg13 = $parameter;
	}

	if (uc $option eq "IMAGE_MPAANR") {
		$image_mpaanr = $parameter;
	}

	if (uc $option eq "IMAGE_MPAAR") {
		$image_mpaar = $parameter;
	}

	if (uc $option eq "IMAGE_MPAANC17") {
		$image_mpaanc17 = $parameter;
	}

	if (uc $option eq "SHOWRTVTEXT") {
		$showrtvtext = $parameter;
	}

	if (uc $option eq "ALLOWTITLEEDIT") {
		$allowtitleedit = $parameter;
	}

	if (uc $option eq "SKIPVERSIONCHECK") {
		$skipversioncheck = $parameter;
	}

	if (uc $option eq "SHOWSCHEDULEBAR") {
		$showschedulebar = $parameter;
	}

	if (uc $option eq "GRIDENDOVERLAP") {
		$grid_end_overlap = $parameter;
	}

	if (uc $option eq "GRIDLEEWAYSECOND") {
		$grid_leeway_second = $parameter;
	}

	if (uc $option eq "DEFAULTMODE") {
		$default_mode = $parameter;
	}
		
	if (uc $option eq "PRIMETIMESTART") {
		$primetime_start = $parameter;
	}

	if (uc $option eq "RTV_UPDATESLEEPSECONDS") {
		$rtv_updatesleepseconds = $parameter;
	}

	if (uc $option eq "RTV_ALLOWDELETE") {
		$rtv_allowdelete = $parameter;
	}

	if ((uc $option eq "USINGAPACHE") || (uc $option eq "SUPRESSHTTPHEADER")) {
		$supresshttpheader = $parameter;
	}

	if (uc $option eq "SUPRESSCONTENTTYPE") {
		$supresscontenttype = $parameter;
	}

	if ($specialdebug ) { 
		print "loadReplayGuideOptions::exiting\n";
	}

	return 1;

}

1;

