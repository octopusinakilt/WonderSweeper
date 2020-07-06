CREATE TABLE `server_info` (
  `server_info_id` int(10) unsigned NOT NULL auto_increment,
  `enviroment` varchar(25) NOT NULL default '',
  `server_name` varchar(15) NOT NULL default '',
  `port` varchar(5) NOT NULL,
  `username` varchar(25) NOT NULL default '',
  `password` varchar(25) NOT NULL default '',
  `dd` varchar(1) NOT NULL default '0',
  `path` varchar(45) NOT NULL default '',
  `current_mailbox_path` varchar(45) NOT NULL default '0',
  `sap_processed_directory` varchar(45) NOT NULL,
  `host_key` varchar(45) NOT NULL,
  `user_key` varchar(45) NOT NULL,
  PRIMARY KEY  (`server_info_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
INSERT INTO `server_info` VALUES (2,'Kronos-DEV','CINAP2505','22','ftpuser','!F$t$P53rver','O','intf/cinap2505/inb/pending','/Kronos-DEV/outbox','','Cinap2505','Cinap2505'),(3,'Kronos-PROD','STRAP1505','','ftpusr','ftpusr1505','O','intf/strap1505/inb/pending','','','',''),(5,'Goedi-Ftpusr','GOEDI','21','ftpusr','ftpusr','O','/intf/gis/inb/pending','','','',''),(6,'Goedi-Gsprod6','GOEDI','21','gsprod6','gsprod6','O','','','','',''),(7,'Goedi-Gsprod','GOEDI','21','gsprod','gsprod','O','','','','',''),(8,'Sap-RP1FI','westgis01','22','ftpusr','ftpusr1','O','/intf/rp1/inb/fi/pending','/Sap-RP1FI/outbox','','westgis01','test_bp_connection'),(9,'Sap-RP1BW','westgis01','22','ftpusr','ftpusr1','O','/intf/rp1/inb/bw/pending','/Sap-RP1BW/outbox','','westgis01','test_bp_connection'),(10,'Sap-RP1HR','westgis01','22','ftpusr','ftpusr1','O','/intf/rp1/inb/hr/pending','/Sap-RP1HR/outbox','','westgis01','test_bp_connection'),(11,'Sap-RP1MM','westgis01','22','ftpusr','ftpusr1','O','/intf/rp1/inb/mm/pending','/Sap-RP1MM/outbox','','westgis01','test_bp_connection'),(15,'Sap-BP1BW','westgis01','22','ftpusr','ftpusr1','O','/intf/bp1/inb/bw/pending','/Sap-BP1BW/outbox','','westgis01','test_bp_connection'),(26,'Sap-RQ1FI','westgis01','22','ftpusr','ftpusr1','O','/intf/rq1/inb/fi/pending','/Sap-RQ1FI/outbox','','westgis01','test_bp_connection'),(27,'Sap-RQ1BW','westgis01','22','ftpusr','ftpusr1','O','/intf/rq1/inb/bw/pending','/Sap-RQ1BW/outbox','','westgis01','test_bp_connection'),(28,'Sap-RQ1HR','westgis01','22','ftpusr','ftpusr1','O','/intf/rq1/inb/hr/pending','/Sap-RQ1HR/outbox','','westgis01','test_bp_connection'),(29,'Sap-RQ1MM','westgis01','22','ftpusr','ftpusr1','O','/intf/rq1/inb/mm/pending','/Sap-RQ1MM/outbox','','westgis01','test_bp_connection'),(32,'Sap-RQ1FI','westgis01','','ftpusr','ftpusr1','I','/intf/rq1/outb/fi/pending','/Sap-RQ1FI/inbox','/intf/rq1/outb/fi/processed','westgis01','test_bp_connection'),(33,'Goedi-FtpusrTest','GOEDI','21','ftpusr','ftpusr','O','/intf/testgis/inb/pending','','','','');
