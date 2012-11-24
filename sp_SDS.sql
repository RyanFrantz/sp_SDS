USE [master]
GO
/****** Object:  StoredProcedure [dbo].[sp_SDS]    Script Date: 02/15/2012 09:36:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_SDS] 
  @TargetDatabase sysname = NULL,			--  NULL: all dbs
  @Level varchar(10) = 'Database',			--  or "File"
  @UpdateUsage bit = 0,						--  default no update
  @Unit char(2) = 'MB',						--  Megabytes, Kilobytes or Gigabytes
  /* extended vars added to limit/expand what we output -ryanfrantz 20120210 */
  @mode varchar(6) = 'normal',				-- can be normal (default) or simple (less output)
  @allocation_stats varchar(5) = 'false',	-- [true|false]; if true, only display allocation stats
  @reserved_stats varchar(5) = 'false',		-- [true|false]; if true, only display reserved stats
  @nagios varchar(5) = 'false'				-- [true|false]; if true, return Nagios-friendly output

AS

/**************************************************************************************************
**
**  (original) author: Richard Ding
**  date:   4/8/2008
**  usage:  list db size AND path w/o SUMmary
**  test code: sp_SDS   --  default behavior
**             sp_SDS 'maAster'
**             sp_SDS NULL, NULL, 0
**             sp_SDS NULL, 'file', 1, 'GB'
**             sp_SDS 'Test_snapshot', 'Database', 1
**             sp_SDS 'Test', 'File', 0, 'kb'
**             sp_SDS 'pfaids', 'Database', 0, 'gb'
**             sp_SDS 'tempdb', NULL, 1, 'kb'
**
**
**	Note from the author I stumbled upon regarding large databases:
**	"If your database is at TB size, replace dec(10,3) with dev(13,3)."
**	from http://www.sqlmag.com/forums/aft/96836
**	ryanfrantz 20120210
**************************************************************************************************/

SET NOCOUNT ON;

IF @TargetDatabase IS NOT NULL AND DB_ID(@TargetDatabase) IS NULL
  BEGIN
    RAISERROR(15010, -1, -1, @TargetDatabase);
    RETURN (-1)
  END

/*
 only call the below code if we're asking about a specific database
*/
if @TargetDatabase IS NOT NULL
/* lifted from sp_spaceused */
declare @id	int			-- The object id that takes up space
		,@type	character(2) -- The object type.
		,@pages	bigint			-- Working variable for size calc.
		,@dbname sysname
		,@dbsize bigint
		,@logsize bigint
		,@reservedpages  bigint
		,@usedpages  bigint
		,@rowCount bigint

select @dbname = @TargetDatabase

begin
	set @dbname = @TargetDatabase
	/* we need to make this dynamic SQL to handle calls for specific databases' details */
	/*
	select @dbsize = sum(convert(bigint,case when status & 64 = 0 then size else 0 end))
		, @logsize = sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))
		from dbo.sysfiles
	*/
	declare @sys_files table (
		size int,
		status int
	)
	insert into @sys_files
		exec(N'SELECT size, status FROM ' + @dbname + '.dbo.sysfiles')
	
	select @dbsize = sum(convert(bigint,case when status & 64 = 0 then size else 0 end))
		, @logsize = sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))
		from @sys_files

	-- table variable for 'sys.partitions'	
	declare @sys_partitions table (
		partition_id bigint,
		object_id int,
		index_id int,
		partition_number int,
		hobt_id bigint,	
		rows bigint,
		filestream_filegroup_id smallint,
		data_compression tinyint,
		data_compression_desc nvarchar(60)	
	)
	insert into @sys_partitions
		exec(N'SELECT * FROM ' + @dbname + '.sys.partitions')

	-- table variable for 'sys.allocation_units'		
	declare @sys_allocation_units table (
		allocation_unit_id bigint,
		type tinyint,
		type_desc nvarchar(60),
		container_id bigint,
		data_space_id int,
		total_pages bigint,	
		used_pages bigint,
		data_pages bigint
	)
	insert into @sys_allocation_units
		exec(N'SELECT * FROM ' + @dbname + '.sys.allocation_units')
	
	-- table variable for 'sys.internal_tables'
	declare @sys_internal_tables table (
		name nvarchar(128),
		object_id int,
		principal_id int,
		schema_id int,
		parent_object_id int,
		type char(2),
		type_desc nvarchar(60),	
		create_date datetime,
		modify_date datetime,
		is_ms_shipped bit,
		is_published bit,
		is_schema_published bit,
		internal_type tinyint,
		internal_type_desc nvarchar(60),
		parent_id int,
		parent_minor_id int,
		lob_data_space_id int,
		filestream_data_space_id int
	)
	insert into @sys_internal_tables
		exec(N'SELECT * FROM ' + @dbname + '.sys.internal_tables')
	
	
	select @reservedpages = sum(a.total_pages),
		@usedpages = sum(a.used_pages),
		@pages = sum(
				CASE
					-- XML-Index and FT-Index internal tables are not considered "data", but is part of "index_size"
					When it.internal_type IN (202,204,211,212,213,214,215,216) Then 0
					When a.type <> 1 Then a.used_pages
					When p.index_id < 2 Then a.data_pages
					Else 0
				END
			)
	/* we need to make this dynamic SQL to handle calls for specific databases' details */
	from @sys_partitions p join @sys_allocation_units a on p.partition_id = a.container_id
		left join @sys_internal_tables it on p.object_id = it.object_id

	/* BEGIN @allocation_stats */
	/* unallocated space could not be negative */
	if @allocation_stats = 'true'
	begin
	select 
		database_name = @dbname,
		database_size = ltrim(str((convert (dec (15,2),@dbsize) + convert (dec (15,2),@logsize)) 
			* 8192 / 1048576,15,2) + ' MB'),
		'unallocated space' = ltrim(str((case when @dbsize >= @reservedpages then
			(convert (dec (15,2),@dbsize) - convert (dec (15,2),@reservedpages)) 
			* 8192 / 1048576 else 0 end),15,2) + ' MB')
	return(0)
	end
	/* END @allocation_stats */

	/* BEGIN @reserved_stats */
	if @reserved_stats = 'true'
	begin
	/*
	**  Now calculate the summary data.
	**  reserved: sum(reserved) where indid in (0, 1, 255)
	** data: sum(data_pages) + sum(text_used)
	** index: sum(used) where indid in (0, 1, 255) - data
	** unused: sum(reserved) - sum(used) where indid in (0, 1, 255)
	*/
	select
		reserved = ltrim(str(@reservedpages * 8192 / 1024.,15,0) + ' KB'),
		data = ltrim(str(@pages * 8192 / 1024.,15,0) + ' KB'),
		index_size = ltrim(str((@usedpages - @pages) * 8192 / 1024.,15,0) + ' KB'),
		unused = ltrim(str((@reservedpages - @usedpages) * 8192 / 1024.,15,0) + ' KB')
	return(0)
	end
	/* END @reserved_stats */
end

IF OBJECT_ID('tempdb.dbo.##Tbl_CombinedInfo', 'U') IS NOT NULL
  DROP TABLE dbo.##Tbl_CombinedInfo;

IF OBJECT_ID('tempdb.dbo.##Tbl_DbFileStats', 'U') IS NOT NULL
  DROP TABLE dbo.##Tbl_DbFileStats;

IF OBJECT_ID('tempdb.dbo.##Tbl_ValidDbs', 'U') IS NOT NULL
  DROP TABLE dbo.##Tbl_ValidDbs;

IF OBJECT_ID('tempdb.dbo.##Tbl_Logs', 'U') IS NOT NULL
  DROP TABLE dbo.##Tbl_Logs;

CREATE TABLE dbo.##Tbl_CombinedInfo (
  DatabaseName sysname NULL, 
  [type] VARCHAR(10) NULL, 
  LogicalName sysname NULL,
  T dec(10, 2) NULL,
  U dec(10, 2) NULL,
  [U(%)] dec(5, 2) NULL,
  F dec(10, 2) NULL,
  [F(%)] dec(5, 2) NULL,
  PhysicalName sysname NULL );

CREATE TABLE dbo.##Tbl_DbFileStats (
  Id int identity, 
  DatabaseName sysname NULL, 
  FileId int NULL, 
  FileGroup int NULL, 
  TotalExtents bigint NULL, 
  UsedExtents bigint NULL, 
  Name sysname NULL, 
  FileName varchar(255) NULL );

CREATE TABLE dbo.##Tbl_ValidDbs (
  Id int identity, 
  Dbname sysname NULL );

CREATE TABLE dbo.##Tbl_Logs (
  DatabaseName sysname NULL, 
  LogSize dec (10, 2) NULL, 
  LogSpaceUsedPercent dec (5, 2) NULL,
  Status int NULL );

DECLARE @Ver varchar(10), 
        @DatabaseName sysname, 
        @Ident_last int, 
        @String varchar(2000),
        @BaseString varchar(2000);

SELECT @DatabaseName = '', 
       @Ident_last = 0, 
       @String = '', 
       @Ver = CASE WHEN @@VERSION LIKE '%9.0%' THEN 'SQL 2005' 
                   WHEN @@VERSION LIKE '%8.0%' THEN 'SQL 2000' 
                   WHEN @@VERSION LIKE '%10.0%' THEN 'SQL 2008' 
              END;

SELECT @BaseString = 
' SELECT DB_NAME(), ' + 
CASE WHEN @Ver = 'SQL 2000' THEN 'CASE WHEN status & 0x40 = 0x40 THEN ''Log''  ELSE ''Data'' END' 
  ELSE ' CASE type WHEN 0 THEN ''Data'' WHEN 1 THEN ''Log'' WHEN 4 THEN ''Full-text'' ELSE ''reserved'' END' END + 
', name, ' + 
CASE WHEN @Ver = 'SQL 2000' THEN 'filename' ELSE 'physical_name' END + 
', size*8.0/1024.0 FROM ' + 
CASE WHEN @Ver = 'SQL 2000' THEN 'sysfiles' ELSE 'sys.database_files' END + 
' WHERE '
+ CASE WHEN @Ver = 'SQL 2000' THEN ' HAS_DBACCESS(DB_NAME()) = 1' ELSE 'state_desc = ''ONLINE''' END + '';

SELECT @String = 'INSERT INTO dbo.##Tbl_ValidDbs SELECT name FROM ' + 
                 CASE WHEN @Ver = 'SQL 2000' THEN 'master.dbo.sysdatabases' 
                      WHEN @Ver IN ('SQL 2005', 'SQL 2008') THEN 'master.sys.databases' 
                 END + ' WHERE HAS_DBACCESS(name) = 1 ORDER BY name ASC';
EXEC (@String);

INSERT INTO dbo.##Tbl_Logs EXEC ('DBCC SQLPERF (LOGSPACE) WITH NO_INFOMSGS');

--  For data part
IF @TargetDatabase IS NOT NULL
  BEGIN
    SELECT @DatabaseName = @TargetDatabase;
    IF @UpdateUsage <> 0 AND DATABASEPROPERTYEX (@DatabaseName,'Status') = 'ONLINE' 
          AND DATABASEPROPERTYEX (@DatabaseName, 'Updateability') <> 'READ_ONLY'
      BEGIN
        SELECT @String = 'USE [' + @DatabaseName + '] DBCC UPDATEUSAGE (0)';
        PRINT '*** ' + @String + ' *** ';
        EXEC (@String);
        PRINT '';
      END

    SELECT @String = 'INSERT INTO dbo.##Tbl_CombinedInfo (DatabaseName, type, LogicalName, PhysicalName, T) ' + @BaseString; 

    INSERT INTO dbo.##Tbl_DbFileStats (FileId, FileGroup, TotalExtents, UsedExtents, Name, FileName)
          EXEC ('USE [' + @DatabaseName + '] DBCC SHOWFILESTATS WITH NO_INFOMSGS');
    EXEC ('USE [' + @DatabaseName + '] ' + @String);

    UPDATE dbo.##Tbl_DbFileStats SET DatabaseName = @DatabaseName; 
  END
ELSE
  BEGIN
    WHILE 1 = 1
      BEGIN
        SELECT TOP 1 @DatabaseName = Dbname FROM dbo.##Tbl_ValidDbs WHERE Dbname > @DatabaseName ORDER BY Dbname ASC;
        IF @@ROWCOUNT = 0
          BREAK;
        IF @UpdateUsage <> 0 AND DATABASEPROPERTYEX (@DatabaseName, 'Status') = 'ONLINE' 
              AND DATABASEPROPERTYEX (@DatabaseName, 'Updateability') <> 'READ_ONLY'
          BEGIN
            SELECT @String = 'DBCC UPDATEUSAGE (''' + @DatabaseName + ''') ';
            PRINT '*** ' + @String + '*** ';
            EXEC (@String);
            PRINT '';
          END

        SELECT @Ident_last = ISNULL(MAX(Id), 0) FROM dbo.##Tbl_DbFileStats;

        SELECT @String = 'INSERT INTO dbo.##Tbl_CombinedInfo (DatabaseName, type, LogicalName, PhysicalName, T) ' + @BaseString; 

        EXEC ('USE [' + @DatabaseName + '] ' + @String);

        INSERT INTO dbo.##Tbl_DbFileStats (FileId, FileGroup, TotalExtents, UsedExtents, Name, FileName)
          EXEC ('USE [' + @DatabaseName + '] DBCC SHOWFILESTATS WITH NO_INFOMSGS');

        UPDATE dbo.##Tbl_DbFileStats SET DatabaseName = @DatabaseName WHERE Id BETWEEN @Ident_last + 1 AND @@IDENTITY;
      END
  END

--  set used size for data files, do not change total obtained from sys.database_files as it has for log files
UPDATE dbo.##Tbl_CombinedInfo 
SET U = s.UsedExtents*8*8/1024.0 
FROM dbo.##Tbl_CombinedInfo t JOIN dbo.##Tbl_DbFileStats s 
ON t.LogicalName = s.Name AND s.DatabaseName = t.DatabaseName;

--  set used size and % values for log files:
UPDATE dbo.##Tbl_CombinedInfo 
SET [U(%)] = LogSpaceUsedPercent, 
U = T * LogSpaceUsedPercent/100.0
FROM dbo.##Tbl_CombinedInfo t JOIN dbo.##Tbl_Logs l 
ON l.DatabaseName = t.DatabaseName 
WHERE t.type = 'Log';

UPDATE dbo.##Tbl_CombinedInfo SET F = T - U, [U(%)] = U*100.0/T;

UPDATE dbo.##Tbl_CombinedInfo SET [F(%)] = F*100.0/T;

IF UPPER(ISNULL(@Level, 'DATABASE')) = 'FILE'
  BEGIN
    IF @Unit = 'KB'
      UPDATE dbo.##Tbl_CombinedInfo
      SET T = T * 1024, U = U * 1024, F = F * 1024;

    IF @Unit = 'GB'
      UPDATE dbo.##Tbl_CombinedInfo
      SET T = T / 1024, U = U / 1024, F = F / 1024;

    SELECT DatabaseName AS 'Database',
      type AS 'Type',
      LogicalName,
      T AS 'Total',
      U AS 'Used',
      [U(%)] AS 'Used (%)',
      F AS 'Free',
      [F(%)] AS 'Free (%)',
      PhysicalName
      FROM dbo.##Tbl_CombinedInfo 
      WHERE DatabaseName LIKE ISNULL(@TargetDatabase, '%') 
      ORDER BY DatabaseName ASC, type ASC;

    SELECT CASE WHEN @Unit = 'GB' THEN 'GB' WHEN @Unit = 'KB' THEN 'KB' ELSE 'MB' END AS 'SUM',
        SUM (T) AS 'TOTAL', SUM (U) AS 'USED', SUM (F) AS 'FREE' FROM dbo.##Tbl_CombinedInfo;
  END

IF UPPER(ISNULL(@Level, 'DATABASE')) = 'DATABASE'
  BEGIN
    DECLARE @Tbl_Final TABLE (
      DatabaseName sysname NULL,
      TOTAL dec (10, 2),
      [=] char(1),
      used dec (10, 2),
      [used (%)] dec (5, 2),
      [+] char(1),
      free dec (10, 2),
      [free (%)] dec (5, 2),
      [==] char(2),
      Data dec (10, 2),
      Data_Used dec (10, 2),
      [Data_Used (%)] dec (5, 2),
      Data_Free dec (10, 2),
      [Data_Free (%)] dec (5, 2),
      [++] char(2),
      Log dec (10, 2),
      Log_Used dec (10, 2),
      [Log_Used (%)] dec (5, 2),
      Log_Free dec (10, 2),
      [Log_Free (%)] dec (5, 2) );

    INSERT INTO @Tbl_Final
      SELECT x.DatabaseName, 
           x.Data + y.Log AS 'TOTAL', 
           '=' AS '=', 
           x.Data_Used + y.Log_Used AS 'U',
           (x.Data_Used + y.Log_Used)*100.0 / (x.Data + y.Log)  AS 'U(%)',
           '+' AS '+',
           x.Data_Free + y.Log_Free AS 'F',
           (x.Data_Free + y.Log_Free)*100.0 / (x.Data + y.Log)  AS 'F(%)',
           '==' AS '==',
           x.Data, 
           x.Data_Used, 
           x.Data_Used*100/x.Data AS 'D_U(%)',
           x.Data_Free, 
           x.Data_Free*100/x.Data AS 'D_F(%)',
           '++' AS '++', 
           y.Log, 
           y.Log_Used, 
           y.Log_Used*100/y.Log AS 'L_U(%)',
           y.Log_Free, 
           y.Log_Free*100/y.Log AS 'L_F(%)'
      FROM 
      ( SELECT d.DatabaseName, 
               SUM(d.T) AS 'Data', 
               SUM(d.U) AS 'Data_Used', 
               SUM(d.F) AS 'Data_Free' 
          FROM dbo.##Tbl_CombinedInfo d WHERE d.type = 'Data' GROUP BY d.DatabaseName ) AS x
      JOIN 
      ( SELECT l.DatabaseName, 
               SUM(l.T) AS 'Log', 
               SUM(l.U) AS 'Log_Used', 
               SUM(l.F) AS 'Log_Free' 
          FROM dbo.##Tbl_CombinedInfo l WHERE l.type = 'Log' GROUP BY l.DatabaseName ) AS y
      ON x.DatabaseName = y.DatabaseName;

    IF @Unit = 'KB'
      UPDATE @Tbl_Final SET TOTAL = TOTAL * 1024,
      used = used * 1024,
      free = free * 1024,
      Data = Data * 1024,
      Data_Used = Data_Used * 1024,
      Data_Free = Data_Free * 1024,
      Log = Log * 1024,
      Log_Used = Log_Used * 1024,
      Log_Free = Log_Free * 1024;

     IF @Unit = 'GB'
      UPDATE @Tbl_Final SET TOTAL = TOTAL / 1024,
      used = used / 1024,
      free = free / 1024,
      Data = Data / 1024,
      Data_Used = Data_Used / 1024,
      Data_Free = Data_Free / 1024,
      Log = Log / 1024,
      Log_Used = Log_Used / 1024,
      Log_Free = Log_Free / 1024;

      DECLARE @GrantTotal dec(11, 2);
      SELECT @GrantTotal = SUM(TOTAL) FROM @Tbl_Final;

     IF @Mode = 'simple'
      IF @nagios = 'true'
		  SELECT 
		  DatabaseName AS 'DATABASE',
		  TOTAL AS 'DATABASE TOTAL', 
		  CONVERT(VARCHAR(12), Data) AS 'DATA TOTAL',
		  CONVERT(VARCHAR(12), Data_Used) AS 'DATA USED',
		  CONVERT(VARCHAR(12), [Data_Used (%)]) AS 'DATA USED  (%)',
		  CONVERT(VARCHAR(12), Log) AS 'LOG TOTAL',
		  CONVERT(VARCHAR(12), Log_Used) AS 'LOG USED',
		  CONVERT(VARCHAR(12), [Log_Used (%)]) AS 'LOG USED  (%)'
			FROM @Tbl_Final 
			WHERE DatabaseName LIKE ISNULL(@TargetDatabase, '%')
			ORDER BY DatabaseName ASC;
      ELSE  
		  SELECT 
		  DatabaseName AS 'DATABASE',
		  TOTAL AS 'DATABASE TOTAL', 
		  [=],
		  CONVERT(VARCHAR(12), Data) + '  (' + CONVERT(VARCHAR(12), Data_Used) + ',  ' + 
		  CONVERT(VARCHAR(12), [Data_Used (%)]) + '%)' AS 'DATA  (used,  %)',
		  [+],
		  CONVERT(VARCHAR(12), Log) + '  (' + CONVERT(VARCHAR(12), Log_Used) + ',  ' + 
		  CONVERT(VARCHAR(12), [Log_Used (%)]) + '%)' AS 'LOG  (used,  %)'
			FROM @Tbl_Final 
			WHERE DatabaseName LIKE ISNULL(@TargetDatabase, '%')
			ORDER BY DatabaseName ASC;
        
     ELSE
      IF @nagios = 'true'
		  SELECT 
		  CONVERT(dec(10, 2), TOTAL*100.0/@GrantTotal) AS 'WEIGHT (%)', 
		  DatabaseName AS 'DATABASE',
		  CONVERT(VARCHAR(12), used) AS 'DATABASE USED',
		  CONVERT(VARCHAR(12), free) AS 'DATABASE FREE',
		  TOTAL AS 'DATABASE TOTAL', 
		  CONVERT(VARCHAR(12), [used (%)]) AS 'DATABASE USED  (%)',
		  CONVERT(VARCHAR(12), [free (%)]) AS 'DATABASE FREE  (%)',
		  CONVERT(VARCHAR(12), Data) AS 'DATA TOTAL',
		  CONVERT(VARCHAR(12), Data_Used) AS 'DATA USED',
		  CONVERT(VARCHAR(12), [Data_Used (%)]) AS 'DATA USED  (%)',
		  CONVERT(VARCHAR(12), Log) AS 'LOG TOTAL',
		  CONVERT(VARCHAR(12), Log_Used) AS 'LOG USED',
		  CONVERT(VARCHAR(12), [Log_Used (%)]) AS 'LOG USED  (%)'
			FROM @Tbl_Final 
			WHERE DatabaseName LIKE ISNULL(@TargetDatabase, '%')
			ORDER BY DatabaseName ASC;
      ELSE  
		  SELECT 
		  CONVERT(dec(10, 2), TOTAL*100.0/@GrantTotal) AS 'WEIGHT (%)', 
		  DatabaseName AS 'DATABASE',
		  CONVERT(VARCHAR(12), used) + '  (' + CONVERT(VARCHAR(12), [used (%)]) + ' %)' AS 'DATABASE USED  (%)',
		  [+],
		  CONVERT(VARCHAR(12), free) + '  (' + CONVERT(VARCHAR(12), [free (%)]) + ' %)' AS 'DATABASE FREE  (%)',
		  [=],
		  TOTAL AS 'DATABASE TOTAL', 
		  [=],
		  CONVERT(VARCHAR(12), Data) + '  (' + CONVERT(VARCHAR(12), Data_Used) + ',  ' + 
		  CONVERT(VARCHAR(12), [Data_Used (%)]) + '%)' AS 'DATA  (used,  %)',
		  [+],
		  CONVERT(VARCHAR(12), Log) + '  (' + CONVERT(VARCHAR(12), Log_Used) + ',  ' + 
		  CONVERT(VARCHAR(12), [Log_Used (%)]) + '%)' AS 'LOG  (used,  %)'
			FROM @Tbl_Final 
			WHERE DatabaseName LIKE ISNULL(@TargetDatabase, '%')
			ORDER BY DatabaseName ASC;
      
    IF @TargetDatabase IS NULL
      SELECT CASE WHEN @Unit = 'GB' THEN 'GB' WHEN @Unit = 'KB' THEN 'KB' ELSE 'MB' END AS 'SUM', 
      SUM (used) AS 'USED', 
      SUM (free) AS 'FREE', 
      SUM (TOTAL) AS 'TOTAL', 
      SUM (Data) AS 'DATA', 
      SUM (Log) AS 'LOG' 
      FROM @Tbl_Final;
  END

RETURN (0)

