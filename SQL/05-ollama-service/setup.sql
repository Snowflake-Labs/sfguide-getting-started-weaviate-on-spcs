-- Make sure you finished the common setup.sql
-- before running this setup.sql

-- Compute Pool --
USE ROLE SYSADMIN;
CREATE COMPUTE POOL IF NOT EXISTS OLLAMA_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = GPU_NV_M
  AUTO_RESUME = true;

DESCRIBE COMPUTE POOL OLLAMA_POOL;

-- Put spec in stage --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
PUT file:///path/to/ollama.yaml @yaml_stage overwrite=true auto_compress=false;

-- Service --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
CREATE SERVICE  OLLAMA
  IN COMPUTE POOL OLLAMA_POOL
  FROM @YAML_STAGE
  SPEC='ollama.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1;

-- Confirm service is running --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
CALL SYSTEM$GET_SERVICE_STATUS('ollama');
