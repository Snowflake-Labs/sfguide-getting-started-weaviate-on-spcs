USE ROLE ACCOUNTADMIN;

DROP SERVICE WEAVIATE;
DROP SERVICE JUPYTER;
DROP SERVICE TEXT2VEC;

DROP COMPUTE POOL WEAVIATE_COMPUTE_POOL;
DROP COMPUTE POOL JUPYTER_COMPUTE_POOL;
DROP COMPUTE POOL TEXT2VEC_COMPUTE_POOL;


DROP DATABASE WEAVIATE_DB_001;

DROP WAREHOUSE WEAVIATE_WAREHOUSE;

DROP USER weaviate_user;

DROP ROLE WEAVIATE_ROLE;

DROP SECURITY INTEGRATION SNOWSERVICES_INGRESS_OAUTH;