-- Creates the empty schemas this project expects in a fresh target database.
-- Run once per new database (dev/test/prod) before the first `dbt run`.
--
--   sqlcmd -S sqlbi01.database.windows.net -d <YOUR_DATABASE> -G -i scripts/setup_schemas.sql

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'vault')
    EXEC('CREATE SCHEMA vault');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'mart')
    EXEC('CREATE SCHEMA mart');
