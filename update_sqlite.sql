DROP TABLE channels;

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
