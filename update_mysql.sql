# MySQL 
# Personal ReplayGuide
# Update Table Script
#
#--------------------------------------------------------

use tvlistings;

ALTER TABLE channels 
	ADD displaynumber int(10) unsigned,
	ADD postalcode varchar(16),
	ADD systemtype varchar(16),
	ADD lineupname varchar(32),
	ADD lineupdevice varchar(32);
