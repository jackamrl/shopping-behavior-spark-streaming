-- =====================================================================
-- Mise en place Snowflake : bases, warehouses, rôles (moindre privilège)
-- À exécuter une fois avec le rôle ACCOUNTADMIN dans Snowsight.
-- =====================================================================
use role accountadmin;

-- Warehouses séparés par usage, taille XS, arrêt après 60 s d'inactivité
create warehouse if not exists LOADING_WH   warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true;
create warehouse if not exists TRANSFORM_WH warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true;
create warehouse if not exists REPORTING_WH warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true;

-- Bases : RAW (donnée brute chargée), ANALYTICS (écrite par dbt)
create database if not exists RAW;
create schema   if not exists RAW.SHOPPING;
create database if not exists ANALYTICS;

-- Rôles
create role if not exists LOADER;        -- charge la donnée brute
create role if not exists TRANSFORMER;   -- dbt : lit RAW, écrit ANALYTICS
create role if not exists REPORTER;      -- Metabase : lecture des marts uniquement
create role if not exists AGENT_READER;  -- agent IA : lecture des marts uniquement

grant role LOADER, TRANSFORMER, REPORTER, AGENT_READER to role sysadmin;

grant usage on warehouse LOADING_WH   to role LOADER;
grant usage on warehouse TRANSFORM_WH to role TRANSFORMER;
grant usage on warehouse REPORTING_WH to role REPORTER;
grant usage on warehouse REPORTING_WH to role AGENT_READER;

-- LOADER : écrit dans RAW
grant usage on database RAW to role LOADER;
grant all on schema RAW.SHOPPING to role LOADER;

-- TRANSFORMER : lit RAW, possède ANALYTICS
grant usage on database RAW to role TRANSFORMER;
grant usage on schema RAW.SHOPPING to role TRANSFORMER;
grant select on all tables in schema RAW.SHOPPING to role TRANSFORMER;
grant select on future tables in schema RAW.SHOPPING to role TRANSFORMER;
grant all on database ANALYTICS to role TRANSFORMER;

-- REPORTER et AGENT_READER : lecture du schéma de prod MARTS seulement
-- (à relancer après le premier `dbt build --target prod`, qui crée le schéma)
grant usage on database ANALYTICS to role REPORTER;
grant usage on database ANALYTICS to role AGENT_READER;
-- grant usage on schema ANALYTICS.MARTS to role REPORTER;
-- grant select on all tables in schema ANALYTICS.MARTS to role REPORTER;
-- grant select on future tables in schema ANALYTICS.MARTS to role REPORTER;
-- grant usage on schema ANALYTICS.MARTS to role AGENT_READER;
-- grant select on all tables in schema ANALYTICS.MARTS to role AGENT_READER;
-- grant select on future tables in schema ANALYTICS.MARTS to role AGENT_READER;

-- Attribuer les rôles à votre utilisateur
grant role LOADER, TRANSFORMER, REPORTER, AGENT_READER to user <VOTRE_USER>;
