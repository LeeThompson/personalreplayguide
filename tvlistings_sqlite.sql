CREATE TABLE schedule (
	scheduleid INTEGER PRIMARY KEY NOT NULL,
	programid int(10) NOT NULL,
	replayid int(10) NOT NULL,
	firstrun tinyint(1) NOT NULL,
	guaranteed tinyint(1) NOT NULL,
	theme tinyint(1) NOT NULL,
	recurring tinyint(1) NOT NULL,
	manual tinyint(1) NOT NULL,
	conflict tinyint(1) NOT NULL,
	created int(10) NOT NULL,
	padbefore int(10) NOT NULL,
	padafter int(10) NOT NULL        
);

CREATE TABLE castcrew (
	castcrewid INTEGER PRIMARY KEY NOT NULL,
	tmsprogramid varchar(12) NOT NULL,
	role int(10) NOT NULL,
	surname varchar(64),
	givenname varchar(64)         
);

CREATE TABLE channels (
	channelid INTEGER PRIMARY KEY NOT NULL,
	tmsid int(10),
	tuning int(10) NOT NULL,
	displaynumber int(10),
	channel varchar(16),
	display varchar(64),
	iconsrc varchar(255),
	affiliate varchar(32),
	headend varchar(16),
	hidden tinyint(1) NOT NULL,
	postalcode varchar(16),
	systemtype varchar(16),
	lineupname varchar(32),
	lineupdevice varchar(32)
);

CREATE TABLE replayunits (
	replayid INTEGER PRIMARY KEY NOT NULL,
	replayname varchar(16),
	replayaddress varchar(65),
	replayport int(10),
	defaultquality int(10),
	defaultkeep int(10),
	lastsnapshot int(10),
	guideversion int(10),
	replayosversion int(10),
	categories varchar(255)
);

CREATE TABLE tvlistings (
	programid INTEGER PRIMARY KEY NOT NULL,
	tmsprogramid varchar(12),
	tmsid int(10),
	starttime datetime NOT NULL,
	endtime datetime NOT NULL,
	tuning int(10) NOT NULL,
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
	subtitled tinyint(1)
);

CREATE INDEX castcrew_index ON castcrew (
	tmsprogramid, 
	surname, 
	givenname
);

PRAGMA default_synchronous = OFF;
PRAGMA default_cache_size = 4000; 
