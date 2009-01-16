create table bazaarItem (
	assetId varchar(22) binary not null,
	revisionDate bigint not null,
	product varchar(22) binary,
	screenshots varchar(22) binary,
	releaseDate date,
	requirements mediumtext,
	versionNumber varchar(30),
	releaseNotes mediumtext,
	supportUrl text,
	demoUrl text,
	moreInfoUrl text,
	price float not null default 0.00,
	downloadPeriod bigint not null default 31536000,
	groupToDownload varchar(22) binary not null default '7',
	groupToSubscribe varchar(22) binary,
	comments mediumtext,
	averageRating float,
	views int not null default 0,
	downloads int not null default 0,
	primary key (assetId, revisionDate)
);

create table bazaar (
	assetId varchar(22) binary not null,
	revisionDate bigint not null,
    groupToUpload varchar(22) binary not null default '2',
    vendorsOnly tinyint(1) not null default 0,
    autoCreateVendors tinyint(1) not null default 1,
    listLimit int not null default 50,
    templateId char(22) binary not null default 'vhNlRmwdrZivIk1IzEpvYQ',
    bazaarItemTemplateId char(22) binary not null default 'VlkZo8ew56Yns_6WMIU8BQ',
    searchTemplateId char(22) binary not null default 'ddc-E8lgRHBsSzOSr4aNrw',
	primary key (assetId, revisionDate)
);
