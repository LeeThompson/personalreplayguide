#!/usr/bin/perl
#
# Personal ReplayGuide
# by Lee Thompson <thompsonl@logh.net>
# with bits by Kanji T. Bates
#  $Id: rg_database.pl,v 1.5 2003/07/19 13:34:20 pvanbaren Exp $
#
# DATABASE FUNCTIONS
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

use DBI;

my $_version = "Personal ReplayGuide|Database Function Library|1|1|228|Lee Thompson,Philip Van Baren,Kanji T. Bates";

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

my $_lastsqlerror = "";
my $_lastsqlstmt = "";

#---------------------------------------------------------------------------------------
sub CreateDatabase {
	#
	# This will create a database.  
	# This only works with certain drivers.
	#
	# ------------------------------------------------------------------------------

	if ($db_driver eq "SQLite") {
		return 1;
	}

	if ($db_driver eq "ODBC") {
		return 1;
	}

	my $specialdebug = 0;

	my $drh = DBI->install_driver($db_driver);

	if ($specialdebug) {
		writeDebug("DBI driver handle is $drh");
	}

	if ($specialdebug) {
		writeDebug("Values: $db_name, $db_host, $db_user, $db_pass");
	}

	my $rc = $drh->func("createdb", $db_name, $db_host, $db_user, $db_pass, 'admin');

	if ($specialdebug) {
		writeDebug("admin function returned $rc");
	}

	undef $drh;

	return $rc;
}


#---------------------------------------------------------------------------------------
sub InitDSN {
	#
	# Define the global DSN
	#
	# Usage: &InitDSN 
	#
	# NOTE: This must be called before ANYTHING else.
	#
	# ------------------------------------------------------------------------------

	if ($db_host eq "localhost") {
		$db_host = "";
	}

    	if (length($db_host) > 0 ) {
		%DATASOURCE = (
			DSN 	 => "DBI:$db_driver:host=$db_host;database=$db_dsn_name",
			Username => $db_user,
			Password => $db_pass,
			Options  => {
				AutoCommit => 1,
				PrintError => 0,
				RaiseError => 0,
				LongReadLen => 65_535, 
				LongTruncOk => 0,
			},
			usage    => $db_dsn_name,
			desc  	 => "Personal ReplayGuide",
			enabled  => 1,
		);
    	}else{
		%DATASOURCE = (
			DSN 	 => "DBI:$db_driver:$db_dsn_name",
			Username => $db_user,
			Password => $db_pass,
			Options  => {
				AutoCommit => 1,
				PrintError => 0,
				RaiseError => 0,
				LongReadLen => 65_535, 
				LongTruncOk => 0,
			},
			usage    => $db_dsn_name,
			desc  	 => "Personal ReplayGuide",
			enabled  => 1,
		);
    	}
}


#---------------------------------------------------------------------------------------
sub StartDSN{
	#
	# Open a DSN
	#
	# Usage: &StartDSN
	# Returns: DB Handle  
	#
	# ------------------------------------------------------------------------------

	if ($debug > 0) {
		writeDebug("Establishing Connection");
	}

	if ($db_conflict > 0) {
		$_lastsqlerror = "Database Namespace Conflict!";
		return $null;
	}

	my $dbh = DBI->connect( @DATASOURCE{qw( DSN Username Password Options )} );

	if ($dbh eq $null) {
			$_lastsqlerror = $DBI::errstr;
			if ($debug > 0) {
				writeDebug("Failed to establish database handle.");
			}
		}else{
			if ($debug > 0) {
				writeDebug("Database handle established as $dbh");
			}
	}

	if ($db_dsn_name ne $db_name) {
		sqlStmt($dbh,"USE $db_name;");
	}

	if ($debug > 1) {
		writeDebug("Exit");
	}

	return $dbh;

}

#---------------------------------------------------------------------------------------
sub endDSN {
	#
	# Close a DSN
	#
	# Parameters: sql handle
	#	      dsn/connection handle
	# Returns: True (1) 
	#
	# ------------------------------------------------------------------------------

	my $handle = shift;
	my $dhandle = shift;

	if ($debug > 0) {
		writeDebug("Closing Connection");
	}

	if ($handle == 0) {
		$handle = "";
	}


	if ($dhandle == 0) {
		$dhandle = "";
	}


	if ($debug > 0) {
		if (defined $handle) {
			writeDebug("Closing SQL transaction handle $handle");
		}
		if (defined $dhandle) {
			writeDebug("Closing SQL database handle $dhandle");
		}
	}

	if (length($handle) > 0) {
		$handle->finish;
	}

	if (length($dhandle) > 0) {
		$dhandle->disconnect;
	}

	if ($debug > 0) {
		writeDebug("Exit");
	}

	return 1;
}	

#---------------------------------------------------------------------------------------
sub sqlStmt{
	#
	# Send SQL Statement to ODBC/SQL
	#
	# Parameters: database hash
	#	      SQL Statement
	#
	# Usage: sqlStmt (DBHash, Stmt)
	# Returns: SQL Execute Handle
	#
	# ------------------------------------------------------------------------------

	my $db_handle = shift;
	my $sql_stmt = shift;
	my $handle;

	if ($debug > 1) {
		writeDebug("Start($db_handle,$sql_stmt)");
	}	

	$status = 0;

	if ($db_handle eq $null) {
		if ($debug > 1) {
			writeDebug("No DSN Link Established");
		}	
		if ($debug > 1) {
			writeDebug("Exit");
		}	
		return 0;
	}

	if ($sql_stmt eq $null) {
		if ($debug > 1) {
			writeDebug("No SQL Statement");
		}	
		if ($debug > 1) {
			writeDebug("Exit");
		}	
		return 0;
	}


	if ($debug > 1) {
		writeDebug("Database handle is $db_handle");
	}

	$_lastsqlstmt = $sql_stmt;

	$handle = $db_handle->prepare($sql_stmt);


	if ($handle eq $null) {
			writeDebug("Failed to Set Handle ($db_handle)");
			return 0;
		}else{
			if ($debug > 1 ) {
				writeDebug("SQL handle set to $handle for $db_handle");
			}
	}

	if ($debug > 1) {
		writeDebug("Attempting to post $sql_stmt with handle $handle");
	}

	if ($handle->execute) {
			if ($debug > 0) {
				writeDebug("$sql_stmt posted to SQL");
			}
			return $handle;
		}else{
			$_lastsqlerror = $DBI::errstr;

			if ($debug > 0) {
				writeDebug("$sql_stmt failed. Error: $_lastsqlerror");
			}


			return 0;
	}
	
	return 0;

}

#---------------------------------------------------------------------------------------
sub runSQLScript{
	#
	# Execute a SQL script
	#
	# Parameters: filename
	#
	# Usage: runSQLScript(Filename)
	# Returns: 
	#
	#
	# ------------------------------------------------------------------------------

	my $sqlfilename = shift;
	my $sqlscript = "";
	my $retcode = 0;
	my $junk = "";
	my $size = 0;
	my $dataline = "";
	my $buffer = "";
	my $execcount = 0;
	my $abort = 0;
	my $specialdebug = 0;
	my $debug = 0;

	if ($debug > 1) {
		writeDebug("Start($sqlfilename");
	}

	my $db_handle = &StartDSN;

	if ($debug > 1) {
		writeDebug("DSN handle is $db_handle");
	}

	if ($debug > 1) {
		if ($allow_sql_substitutions) {
			writeDebug("Allowing Substitutions");
		}
	}

	if ($specialdebug) {
		writeDebug("allow_sql_substitutions: $allow_sql_substitutions");
	}

	#---------------------------------------------------------------
	# Open the file and start processing
	#---------------------------------------------------------------

	if (open(FHANDLE, $sqlfilename)) {
		if ($debug > 1) {
			writeDebug("File $sqlfilename open");
		}

		while (<FHANDLE>) {
			$dataline = $_;
			chop $dataline;

			if ($debug > 2) {
				writeDebug("$sqlfilename: $dataline");
			}

			if (substr($dataline,0,1) eq "#") {
				$dataline = "";
			}
		
			if ($abort) {
				$dataline = "";
			}
			
			if (($allow_sql_substitutions) && (length($dataline) > 0))  {
				if ($specialdebug) {
					writeDebug("Processing Substitutions");
				}

				#-------------------------------------------------------
				# Modify USE statement
				#-------------------------------------------------------

				if ((uc $dataline) =~ /USE/) {
					my $d_name = $dataline;
					$d_name =~ s/.*use ([^;]*).*/$1/i;

					if ($d_name ne $dataline) {	
						$d_name = trimstring($d_name);

						if ($specialdebug) {
							writeDebug("old dataline: $dataline");
							writeDebug("    database: $d_name -> $db_name");
						}

						$dataline =~ s/$d_name/$db_name/g;

						if ($specialdebug) {
							writeDebug("new dataline: $dataline");
						}	
					}
				}

				#-------------------------------------------------------
				# Modify Table References
				#-------------------------------------------------------

				if (((uc $dataline) =~ /CREATE TABLE/) || ((uc $dataline) =~ /DROP TABLE/) || ((uc $dataline) =~ /TRUNCATE TABLE/) || ((uc $dataline) =~ /OBJECT_ID/) || ((uc $dataline) =~ /ALTER TABLE/)) {
					my $t_name = $dataline;

					if ($dataline =~ /dbo/i) {
						$t_name =~ s/.*\[dbo\].\[([^]]*).*/$1/i;	
						if ($t_name eq $dataline) {
							$t_name =~ s/.*dbo.([^+]*).*/$1/i;	
						}						
					}else{
						if ((uc $dataline) =~ /DROP/) {
							$t_name =~ s/.*table ([^;]*).*/$1/i;	
						}else{
							$t_name =~ s/.*table ([^(]*).*/$1/i;	
						}
						if (((uc $dataline) =~ /ALTER/) && ($tname eq $dataline)) {
							$t_name =~ s/.*table ([^+]*).*/$1/i;	
						}

					}

					if ($t_name ne $dataline) {

						$t_name = trimstring($t_name);

						if ($specialdebug) {
							writeDebug("old dataline: $dataline");
						}
	
						my $nt_name = $t_name;
		
						if ((uc $t_name) eq "SCHEDULE" ) {
							$nt_name = "$db_table_schedule";
						}

						if ((uc $t_name) eq "CHANNELS" ) {
							$nt_name = "$db_table_channels";
						}

						if ((uc $t_name) eq "REPLAYUNITS" ) {
							$nt_name = "$db_table_replayunits";
						}

						if ((uc $t_name) eq "TVLISTINGS" ) {
							$nt_name = "$db_table_tvlistings";
						}

						if ((uc $t_name) eq "CASTCREW" ) {
							$nt_name = "$db_table_castcrew";
						}


						if ($specialdebug) {
							writeDebug("       table: $t_name -> $nt_name");
						}

						$dataline =~ s/$t_name/$nt_name/g;
	
						if ($specialdebug) {
							writeDebug("new dataline: $dataline");
						}
					}
				}

				#-------------------------------------------------------
				# Modify Insert References
				#-------------------------------------------------------

				if ((uc $dataline) =~ /INSERT/) {
					my $t_name = $dataline;

					if ((uc $dataline) =~ /DBO/) {
						$t_name =~ s/.*\[dbo\].\[([^]]*).*/$1/i;	
					}else{
						$t_name =~ s/.*INTO ([^(]*).*/$1/i;	
					}

					if ($t_name ne $dataline) {

						$t_name = trimstring($t_name);

						if ($specialdebug) {
							writeDebug("old dataline: $dataline");
						}
	
						my $nt_name = $t_name;

						if ((uc $t_name) eq "SCHEDULE" ) {
							$nt_name = "$db_table_schedule";
						}

						if ((uc $t_name) eq "CHANNELS" ) {
							$nt_name = "$db_table_channels";
						}

						if ((uc $t_name) eq "REPLAYUNITS" ) {
							$nt_name = "$db_table_replayunits";
						}

						if ((uc $t_name) eq "TVLISTINGS" ) {
							$nt_name = "$db_table_tvlistings";
						}

						if ((uc $t_name) eq "CASTCREW" ) {
							$nt_name = "$db_table_castcrew";
						}

						if ($specialdebug) {
							writeDebug("       table: $t_name -> $nt_name");
						}

						$dataline =~ s/$t_name/$nt_name/g;

						if ($specialdebug) {
							writeDebug("new dataline: $dataline");
						}
					}
				}

				#-------------------------------------------------------
				# Modify Update References
				#-------------------------------------------------------

				if ((uc $dataline) =~ /UPDATE/) {
					my $t_name = $dataline;

					if ((uc $dataline) =~ /DBO/) {
						$t_name =~ s/.*\[dbo\].\[([^]]*).*/$1/i;	
					}else{
						$t_name =~ s/.*UPDATE ([^(]*).*/$1/i;	
					}

					if ($t_name ne $dataline) {

						$t_name = trimstring($t_name);

						if ($specialdebug) {
							writeDebug("old dataline: $dataline");
						}
	
						my $nt_name = $t_name;

						if ((uc $t_name) eq "SCHEDULE" ) {
							$nt_name = "$db_table_schedule";
						}

						if ((uc $t_name) eq "CHANNELS" ) {
							$nt_name = "$db_table_channels";
						}

						if ((uc $t_name) eq "REPLAYUNITS" ) {
							$nt_name = "$db_table_replayunits";
						}

						if ((uc $t_name) eq "TVLISTINGS" ) {
							$nt_name = "$db_table_tvlistings";
						}

						if ((uc $t_name) eq "CASTCREW" ) {
							$nt_name = "$db_table_castcrew";
						}


						if ($specialdebug) {
							writeDebug("       table: $t_name -> $nt_name");
						}

						$dataline =~ s/$t_name/$nt_name/g;

						if ($specialdebug) {
							writeDebug("new dataline: $dataline");
						}
					}
				}

				#-------------------------------------------------------
				# Modify Index References
				#-------------------------------------------------------

				if ((uc $dataline) =~ /INDEX/) {
					my $t_name = $dataline;
	
					$t_name =~ s/.*ON ([^(]*).*/$1/i;	

					if ($t_name ne $dataline) {

						$t_name = trimstring($t_name);

						if ($specialdebug) {
							writeDebug("old dataline: $dataline");
						}
	
						my $nt_name = $t_name;
		
						if ((uc $t_name) eq "SCHEDULE" ) {
							$nt_name = "$db_table_schedule";
						}

						if ((uc $t_name) eq "CHANNELS" ) {
							$nt_name = "$db_table_channels";
						}

						if ((uc $t_name) eq "REPLAYUNITS" ) {
							$nt_name = "$db_table_replayunits";
						}

						if ((uc $t_name) eq "TVLISTINGS" ) {
							$nt_name = "$db_table_tvlistings";
						}

						if ((uc $t_name) eq "CASTCREW" ) {
							$nt_name = "$db_table_castcrew";
						}


						if ($specialdebug) {
							writeDebug("       table: $t_name -> $nt_name");
						}

						$dataline =~ s/$t_name/$nt_name/g;
	
						if ($specialdebug) {
							writeDebug("new dataline: $dataline");
						}
					}
				}


	

			}

			
			#---------------------------------------------------------------
			# If the line is GO and this is ODBC, this is probably MSSQL
			# and we need to send the buffer
			#---------------------------------------------------------------

			if (($dataline eq "GO") && ($db_driver eq "ODBC")) {
				#
				# Microsoft SQL 
				#
				#--------------------------------------------------------

				if ($debug > 1) {
					writeDebug("Using Small Buffer with GO Syntax");
				}

				chop $buffer;
				$buffer .= ";";

				if (!$abort) {
					if ($debug > 1) {
						writeDebug("Executing: $buffer");
					}
		
					my $sql_handle = sqlStmt($db_handle,$buffer);

					if ($debug > 1) {
						writeDebug("Buffer returned SQL handle $sql_handle");
					}

					if ($sql_handle) {
						$retcode = 1;
					}else{
						$retcode = 0;
						$abort = 1;
					}				
		
					$execcount++;

					undef $sql_handle;
					$buffer = "";

					if ($debug > 1) {
						writeDebug("Sent $execcount statements.  Return Code: $retcode.  Abort Flag: $abort");
					}
				}
			}elsif (($dataline eq ");") && (($db_driver eq "SQLite") || ($db_driver eq "mysql")|| ($db_driver eq "ODBC"))) {

				#---------------------------------------------------------------
				# Likewise, if this is SQLite and the line ends with a ;
				#---------------------------------------------------------------

				if ($debug > 1) {
					writeDebug("Using Small Buffer Syntax");
				}

				$buffer .= $dataline . "\n";

				if (!$abort) {
					if ($debug > 1) {
						writeDebug("Executing: $buffer");
					}
		
					my $sql_handle = sqlStmt($db_handle,trimstring($buffer));

					if ($debug > 1) {
						writeDebug("Buffer returned SQL handle $sql_handle");
					}

					if ($sql_handle) {
						$retcode = 1;
					}else{
						$retcode = 0;
						$abort = 1;
					}				
		
					$execcount++;

					undef $sql_handle;
					$buffer = "";

					if ($debug > 1) {
						writeDebug("Sent $execcount statements.  Abort Flag: $abort");
					}
				}
				

			}else{

				#---------------------------------------------------------------
				# Finish processing the dataline if it's not null.
				#---------------------------------------------------------------

				if (length($dataline) > 1) {
					if (($dataline =~ /;/) && (($db_driver eq "SQLite") || ($db_driver eq "mysql") || ($db_driver eq "ODBC"))) {
						#---------------------------------------------------------------
						# If this is a single line and this is SQLite, we need to send
						# the dataline.
						#---------------------------------------------------------------
						
						$buffer .= $dataline . "\n";

						if (!$abort) {
							if ($debug > 1) {
								writeDebug("Executing: $buffer");
							}
			
							my $sql_handle = sqlStmt($db_handle,trimstring($buffer));
		
							if ($debug > 1) {
								writeDebug("Buffer returned SQL handle $sql_handle");
							}

							if ($sql_handle) {
								$retcode = 1;
							}else{
								$retcode = 0;
								$abort = 1;
							}				
		
							$execcount++;
		
							undef $sql_handle;
							$buffer = "";

							if ($debug > 1) {
								writeDebug("Sent $execcount statements.  Abort Flag: $abort");
							}
						}
				
					}else{
						#---------------------------------------------------------------
						# Otherwise we need to add the line to the buffer.
						#---------------------------------------------------------------

						if ($debug > 3) {
							writeDebug("Appending \"$dataline\" to buffer");
						}


						$buffer .= $dataline . "\n";
					}
				}
			}
		}
		close FHANDLE;
		if ($debug > 1) {
			writeDebug("File closed");
		}

	}else{
		if ($debug > 1) {
			writeDebug("DSN ($db_handle) shutting down, could not open $sqlfilename");
		}
		$_lastsqlstmt = "runSQLScript Open $sqlfilename";
		$_lastsqlerror = "runSQLScript could not open $sqlfilename";
		endDSN("",$db_handle);
		return 0;
	}

	#---------------------------------------------------------------
	# If we haven't sent the buffer at all yet, do so now.
	#
	# mysql in particular can accept the entire script in a single
	# transmission.
	#---------------------------------------------------------------

	if ((!$execcount) && (!$abort)) {
		if ($debug > 1) {
			writeDebug("Large Buffer Syntax Detected");
			writeDebug("Executing: $buffer");
		}
		
		my $sql_handle = sqlStmt($db_handle,trimstring($buffer));

		if ($debug > 1) {
			writeDebug("Buffer returned SQL handle $sql_handle");
		}

		if ($sql_handle) {
			$retcode = 1;
			$execcount++;
		}else{
			$retcode = 0;
			$abort = 1;
		}

		if ($debug > 1) {
			writeDebug("Sent $execcount statements.  Abort Flag: $abort");
		}		

	}


	#---------------------------------------------------------------
	# cleanup and bail
	#---------------------------------------------------------------

	if ($debug > 1) {
		writeDebug("Executed: $execcount statements.  Abort Flag: $abort");
	}

	undef $sql_handle;

	if ($debug > 1) {
		writeDebug("DSN: $db_handle closing.   Returning: $retcode");
	}

	endDSN("",$db_handle);

	return $retcode;

}

#----------------------------------------------------------------------------
sub GetLastSQLStmt{
	#
	# Get last SQL Stmt
	#
	# This is stored as a local (library) variable until requested
	#
	# ------------------------------------------------------------------------------

	return $_lastsqlstmt;
}


#----------------------------------------------------------------------------
sub GetLastSQLError{
	#
	# Get last SQL error message
	#
	# This is stored as a local (library) variable until requested
	#
	# ------------------------------------------------------------------------------

	return $_lastsqlerror;
}

#----------------------------------------------------------------------------
sub filterfield {
	#
	# Escape a SQL field
	#
	# Usage: filterfield(String)
	#
	# ------------------------------------------------------------------------------

	if ($debug > 1) {
		writeDebug("Start");
	}	

	my $tempvar = shift;

	if ($debug > 4) {
		writeDebug($tempvar);
	}
	
	if ($tempvar eq $null) {
		return $tempvar;
	}

	$tempvar =~ s/'/''/g;				# Escape quotes
	$tempvar =~ s/"/''/g;				# Escape quotes

	if ($debug > 4) {
		writeDebug($tempvar);
	}

	if ($debug > 1) {
		writeDebug("Exit");
	}	

	return $tempvar;
}


#----------------------------------------------------------------------------
sub timestringtosql{
	#
	# Convert a time string (YYYYMMDDHHMMSS) to SQL time 
	#
	# ------------------------------------------------------------------------------

	my $input_time = shift;
	my $output_time = 0;

	($Y,$M,$D,$h,$m,$s) = unpack 'A4 A2 A2 A2 A2 A2', $input_time;
	$Y = int $Y;
	if ($Y > 0) {
		$output_time = "$Y-$M-$D $h:$m:$s";
	}

	return $output_time;

}

#----------------------------------------------------------------------------
sub sqltotimestring{
	#
	# Convert a SQL time to a time string (YYYYMMDDHHMMSS)
	#
	# ------------------------------------------------------------------------------

	my $input_time = shift;
	my $output_time = 0;

	$output_time = substr($input_time,0,4) . substr($input_time,5,2) . substr($input_time,8,2) . substr($input_time,11,2) . substr($input_time,14,2) . "00";

	return $output_time;

}

#----------------------------------------------------------------------------
sub pruneDatabase{
	#
	# Prune the Database based on a Cut Off Time
	#
	# Parameter: Time (SQL format date/time)
	#	     Returns true or false.
	#
	# ------------------------------------------------------------------------------

	my $cutofftime = shift;
	my $iRetCode = 1;

	my $db_handle = &StartDSN;

	my $Stmt = "DELETE FROM $db_table_tvlistings WHERE starttime < '$cutofftime';";
	
	my $sth = SQLStmt($db_handle,$Stmt);

	if ($sth) {
			$iRetCode = 1;
	    	}else{
			writeDebug("Failed:");
			writeDebug(&GetLastSQLStmt);
			writeDebug(&GetLastSQLError);
			$iRetCode = 0;
	}

	endDSN($sth,$db_handle);

	return $iRetCode;

}

1;

