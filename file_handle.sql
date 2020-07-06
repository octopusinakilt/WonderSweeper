CREATE TABLE `file_handle` (
  `file_handle_id` int(10) unsigned NOT NULL auto_increment,
  `file_handle` varchar(25) NOT NULL default '',
  `mailbox_path` varchar(25) NOT NULL default '',
  `trans_type` varchar(6) NOT NULL default '',
  `outbound_file_handle` varchar(25) NOT NULL default '',
  `outbound_mailbox_path` varchar(25) NOT NULL default '',
  `bp_1_flag` varchar(1) NOT NULL default '',
  `bp_1` varchar(45) NOT NULL default '',
  `bp_2_flag` varchar(1) NOT NULL default '',
  `bp_2` varchar(45) NOT NULL default '',
  `bp_3_flag` varchar(1) NOT NULL default '',
  `bp_3` varchar(45) NOT NULL default '',
  PRIMARY KEY  (`file_handle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
INSERT INTO `file_handle` VALUES (1,'TEST','/Sap-RQ1FI/inbox','A','TESTFILE','/goedi/outbox','N','','N','','N',''),(2,'IHR-KRONOS-LL-CONTRACTS','/GOEDI/inbox','A','IHR-KRONOS-LL-CONTRACTS','/Kronos-DEV/outbox','N','','N','','N',''),(3,'IHR-KRONOS-LL-COST-CENTER','/GOEDI/inbox','A','IHR-KRONOS-LL-COST-CENTER','/Kronos-DEV/outbox','N','','N','','N',''),(4,'IHR-KRONOS-LL-JOBS','/GOEDI/inbox','A','IHR-KRONOS-LL-JOBS','/Kronos-DEV/outbox','N','','N','','N',''),(5,'IHR-KRONOS-LL-PAYROLLAREA','/GOEDI/inbox','A','IHR-KRONOS-LL-PAYROLLAREA','/Kronos-DEV/outbox','N','','N','','N',''),(6,'IHR-KRONOS-LL-PERSAREA','/GOEDI/inbox','A','IHR-KRONOS-LL-PERSAREA','/Kronos-DEV/outbox','N','','N','','N',''),(7,'KRONOS-Minimaster','/GOEDI/inbox','A','KRONOS-Minimaster','/Kronos-DEV/outbox','N','','N','','N',''),(8,'KRONOS2SAPONCYCLE','/Kronos-DEV/inbox','A','KRONOS2SAPONCYCLE','/GOEDI/outbox','N','','N','','N',''),(9,'KRONOS2SAPOFFCYCLE','/Kronos-DEV/inbox','A','KRONOS2SAPOFFCYCLE','/GOEDI/outbox','N','','N','','N',''),(10,'PAYRULENAMES','/Kronos-DEV/inbox','A','PAYRULENAMES','/GOEDI/outbox','N','','N','','N',''),(11,'IHR-KRONOS-LL-CONTRACTS','','','','','','','','','',''),(12,'IHR-KRONOS-LL-COST-CENTER','','','','','','','','','',''),(13,'IHR-KRONOS-LL-JOBS','','','','','','','','','',''),(14,'IHR-KRONOS-LL-PAYROLLAREA','','','','','','','','','',''),(15,'IHR-KRONOS-LL-PERSAREA','','','','','','','','','',''),(16,'KRONOS-Minimaster','','','','','','','','','','');
