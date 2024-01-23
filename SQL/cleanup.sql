-----------Cleanup stuff that costs money---------------
USE ROLE ACCOUNTADMIN;

DROP SERVICE WEAVIATE;
DROP SERVICE JUPYTER;
DROP SERVICE TEXT2VEC;
DROP SERVICE OLLAMA;

DROP COMPUTE POOL WEAVIATE_COMPUTE_POOL;
DROP COMPUTE POOL JUPYTER_COMPUTE_POOL;
DROP COMPUTE POOL TEXT2VEC_COMPUTE_POOL;

----Really clean up everything------

DROP IMAGE REPOSITORY WEAVIATE_PRODUCT_REVIEWS.PUBLIC.WEAVIATE_REPO;

DROP DATABASE WEAVIATE_PRODUCT_REVIEWS.PUBLIC;

DROP WAREHOUSE WEAVIATE_WAREHOUSE;

DROP USER weaviate_user;

DROP ROLE WEAVIATE_ROLE;

DROP SECURITY INTEGRATION SNOWSERVICES_INGRESS_OAUTH;