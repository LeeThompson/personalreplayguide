use tvlistings;

ALTER TABLE dbo.channels 
	ADD [displaynumber] [int] NULL ,
	[postalcode] [nvarchar] (16) NULL ,
	[systemtype] [nvarchar] (16) NULL ,
	[lineupname] [nvarchar] (32) NULL ,
	[lineupdevice] [nvarchar] (32) NULL
GO
