-- Weaviate Database --
USE ROLE SYSADMIN;
DROP DATABASE WEAVIATE_DEMO;

-- Weaviate Warehouse --
USE ROLE SYSADMIN;
DROP WAREHOUSE WEAVIATE_WAREHOUSE;

-- Weaviate User --
USE ROLE USERADMIN;
DROP USER weaviate_user;

-- Weaviate Role --
USE ROLE SECURITYADMIN;
DROP ROLE WEAVIATE_ROLE;

-- OAuth Integration --
USE ROLE ACCOUNTADMIN;
DROP SECURITY INTEGRATION SNOWSERVICES_INGRESS_OAUTH;