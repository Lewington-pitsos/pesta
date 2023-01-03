CREATE TABLE contacts (
  id int NOT NULL auto_increment,
  taskId int NOT NULL,
  fullName varchar(255) NOT NULL default '',
  phoneNumber varchar(255) NOT NULL default '',
  PRIMARY KEY  (id),
  KEY taskId (taskId)
);

CREATE TABLE times (
    id int NOT NULL auto_increment,
    start datetime NOT NULL,
    end datetime NOT NULL,
    PRIMARY KEY  (id),
);

CREATE TABLE tasks (
    id int NOT NULL auto_increment,
    taskType varchar(255) NOT NULL default '',
    activity varchar(255) NOT NULL default '',
    location varchar(255) NOT NULL default '',
    deadline datetime NOT NULL,
    needyness int NOT NULL,
    status varchar(255) NOT NULL,
    PRIMARY KEY  (id),
    KEY contactId (contactId)
);
