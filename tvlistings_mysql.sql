# MySQL 
# Personal ReplayGuide
# Create Table Script
#
#--------------------------------------------------------

use tvlistings;

CREATE TABLE schedule (
	scheduleid int(10) unsigned NOT NULL auto_increment,
	programid int(10) unsigned NOT NULL,
	replayid int(10) unsigned NOT NULL,
	firstrun tinyint(1) NOT NULL,
	guaranteed tinyint(1) NOT NULL,
	theme tinyint(1) NOT NULL,
	recurring tinyint(1) NOT NULL,
	manual tinyint(1) NOT NULL,
	conflict tinyint(1) NOT NULL,
	created int(10) NOT NULL,
	padbefore int(10) NOT NULL,
	padafter int(10) NOT NULL,
	PRIMARY KEY (scheduleid),
  	INDEX (programid, replayid),
  	INDEX (replayid)          
);

CREATE TABLE castcrew (
	castcrewid int(10) unsigned NOT NULL auto_increment,
	tmsprogramid varchar(12) NOT NULL,
	role int(10) unsigned NOT NULL,
	surname varchar(64),
	givenname varchar(64),
	PRIMARY KEY (castcrewid),
  	INDEX (tmsprogramid, role),
  	INDEX (role)          
);

CREATE TABLE channels (
	channelid int(10) unsigned NOT NULL auto_increment,
	tmsid int(10) unsigned,
	tuning int(10) unsigned NOT NULL,
	displaynumber int(10) unsigned,
	channel varchar(16),
	display varchar(64),
	iconsrc varchar(255),
	affiliate varchar(32),
	headend varchar(16),
	hidden tinyint(1) NOT NULL,
	postalcode varchar(16),
	systemtype varchar(16),
	lineupname varchar(32),
	lineupdevice varchar(32),
	PRIMARY KEY (channelid),
  	INDEX (tuning, hidden),
  	INDEX (hidden)          
);

CREATE TABLE replayunits (
	replayid int(10) unsigned NOT NULL auto_increment,
	replayname varchar(16),
	replayaddress varchar(65),
	replayport int(10) unsigned,
	defaultquality int(10) unsigned,
	defaultkeep int(10) unsigned,
	lastsnapshot int(10) unsigned,
	guideversion int(10) unsigned,
	replayosversion int(10) unsigned,
	categories varchar(255),
	PRIMARY KEY (replayid)
);

CREATE TABLE tvlistings (
	programid int(10) unsigned NOT NULL auto_increment,
	tmsprogramid varchar(12),
	tmsid int(10) unsigned,
	starttime datetime NOT NULL,
	endtime datetime NOT NULL,
	tuning int(10) unsigned NOT NULL,
	channel varchar(16),
	title varchar(255),
	subtitle varchar(255),
	description text,
	category varchar(255),
	captions varchar(32),
	advisories varchar(255),
	episodenum varchar(16),
	vchiprating varchar(16),
	mpaarating varchar(16),
	starrating varchar(16),
	movieyear varchar(16),
	stereo tinyint(1),
	repeat tinyint(1),
	movie tinyint(1),
	subtitled tinyint(1),
	PRIMARY KEY (programid),
	KEY (starttime,tuning),
	KEY (endtime,tuning),       
	KEY (starttime,endtime,tuning)   
);


