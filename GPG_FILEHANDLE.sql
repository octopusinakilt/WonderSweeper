/*
   Thursday, May 13, 20102:08:39 PM
   User: 
   Server: corpgissql01
   Database: GISTest
   Application: 
*/

/* To prevent any potential data loss issues, you should review this script in detail before running it outside the context of the database designer.*/
BEGIN TRANSACTION
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON
SET NUMERIC_ROUNDABORT OFF
SET CONCAT_NULL_YIELDS_NULL ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
COMMIT
BEGIN TRANSACTION
GO
ALTER TABLE dbo.GPG_FILEHANDLE
	DROP COLUMN extra_parms
GO
COMMIT
select Has_Perms_By_Name(N'dbo.GPG_FILEHANDLE', 'Object', 'ALTER') as ALT_Per, Has_Perms_By_Name(N'dbo.GPG_FILEHANDLE', 'Object', 'VIEW DEFINITION') as View_def_Per, Has_Perms_By_Name(N'dbo.GPG_FILEHANDLE', 'Object', 'CONTROL') as Contr_Per 