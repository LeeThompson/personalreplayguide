use tvlistings;

CREATE TABLE [dbo].[schedule] (
	[scheduleid]  uniqueidentifier PRIMARY KEY ROWGUIDCOL DEFAULT (newid()) NOT NULL ,
	[programid]  uniqueidentifier NOT NULL,
	[replayid] [int] NOT NULL ,
	[firstrun] [bit] NOT NULL ,
	[guaranteed] [bit] NOT NULL ,
	[theme] [bit] NOT NULL ,
	[recurring] [bit] NOT NULL ,
	[manual] [bit] NOT NULL ,
	[conflict] [bit] NOT NULL ,
	[created] [int] NOT NULL ,
	[padbefore] [int] NOT NULL ,
	[padafter] [int] NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[castcrew] (
	[castcrewid]  uniqueidentifier PRIMARY KEY  ROWGUIDCOL DEFAULT (newid()) NOT NULL ,
	[tmsprogramid] [nvarchar] (12) NOT NULL ,
	[role] [int] NOT NULL ,
	[surname] [nvarchar] (64) NULL ,
	[givenname] [nvarchar] (64) NULL
) ON [PRIMARY]
GO


CREATE TABLE [dbo].[channels] (
	[channelid]  uniqueidentifier PRIMARY KEY  ROWGUIDCOL DEFAULT (newid()) NOT NULL ,
	[tmsid] [int] NULL ,
	[tuning] [int] NOT NULL ,
	[displaynumber] [int] NULL ,
	[channel] [nvarchar] (16) NULL ,
	[display] [nvarchar] (64) NULL ,
	[iconsrc] [nvarchar] (255) NULL ,
	[affiliate] [nvarchar] (32) NULL ,
	[headend] [nvarchar] (16) NULL ,
	[hidden] [bit] NULL ,
	[postalcode] [nvarchar] (16) NULL ,
	[systemtype] [nvarchar] (16) NULL ,
	[lineupname] [nvarchar] (32) NULL ,
	[lineupdevice] [nvarchar] (32) NULL
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[replayunits] (
	[replayid] [int] IDENTITY (1, 1) PRIMARY KEY  NOT NULL ,
	[replayname] [nvarchar] (16) NULL ,
	[replayaddress] [nvarchar] (65) NULL ,
	[replayport] [int] NULL ,
	[defaultquality] [int] NULL ,
	[defaultkeep] [int] NULL ,
	[lastsnapshot] [int] NULL ,
	[guideversion] [int] NULL ,
	[replayosversion] [int] NULL ,
	[categories] [nvarchar] (255) NULL
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[tvlistings] (
	[programid]  uniqueidentifier  PRIMARY KEY ROWGUIDCOL  DEFAULT (newid()) NOT NULL ,
	[tmsprogramid] [nvarchar] (12) NULL ,
	[tmsid] [int] NULL ,
	[starttime] [datetime] NULL ,
	[endtime] [datetime] NULL ,
	[tuning] [int] NULL ,
	[channel] [nvarchar] (16) NULL ,
	[title] [nvarchar] (255) NULL ,
	[subtitle] [nvarchar] (255) NULL ,
	[description] [ntext] NULL ,
	[category] [nvarchar] (255) NULL ,
	[captions] [nvarchar] (32) NULL ,
	[advisories] [nvarchar] (255) NULL ,
	[episodenum] [nvarchar] (16) NULL ,
	[vchiprating] [nvarchar] (16) NULL ,
	[mpaarating] [nvarchar] (16) NULL ,
	[starrating] [nvarchar] (16) NULL ,
	[movieyear] [nvarchar] (16) NULL ,
	[stereo] [bit] NULL ,
	[repeat] [bit] NULL ,
	[movie] [bit] NULL ,
	[subtitled] [bit] NULL 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

