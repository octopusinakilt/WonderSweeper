CREATE TABLE `file_log` (
  `file_log_id` int(10) unsigned NOT NULL auto_increment,
  `file_handle` varchar(45) NOT NULL default '',
  `file_full_name` varchar(45) NOT NULL default '',
  `file_md5` varchar(45) NOT NULL default '',
  `date_processed` varchar(45) NOT NULL default '',
  `status` varchar(45) NOT NULL default '',
  PRIMARY KEY  (`file_log_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
