# Getting Started with Weaviate on SPCS

## 1. Log into Snowflake

Download the [SnowSQL](https://docs.snowflake.com/en/user-guide/snowsql) client. Use the SnowSQL client to connect to Snowflake.

```bash  
snowsql -a "YOURINSTANCE" -u "YOURUSER"
```

It is recommended that you use SnowSQL because you will be uploading files from your local machine to your Snowflake account, but you can also [upload files to stages directly from Snowsight, if you prefer](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui#upload-files-onto-a-named-internal-stage).

## 2. Set up environment

Set up OAUTH integration. This will allow Snowflake to authenticate users of your service.

```sql
-- OAuth Integration --
USE ROLE ACCOUNTADMIN;
CREATE SECURITY INTEGRATION SNOWSERVICES_INGRESS_OAUTH
  TYPE=oauth
  OAUTH_CLIENT=snowservices_ingress
  ENABLED=true;
```

Give the SYSADMIN the ability to bind service endpoints. This will allow the SYSADMIN to create services.

```sql
-- Bind Service Grant
USE ROLE ACCOUNTADMIN;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE SYSADMIN;
```

Create a role, and a user, for the Weaviate instance. We will use this user to log into our Jupyter service later.

```sql
-- Weaviate Role --
USE ROLE SECURITYADMIN;
CREATE ROLE WEAVIATE_ROLE;

-- Weaviate User --
USE ROLE USERADMIN;
CREATE USER weaviate_user
  PASSWORD='weaviate123'
  DEFAULT_ROLE = WEAVIATE_ROLE
  DEFAULT_SECONDARY_ROLES = ('ALL')
  MUST_CHANGE_PASSWORD = FALSE;

-- Grant Role to User --
USE ROLE SECURITYADMIN;
GRANT ROLE WEAVIATE_ROLE TO USER weaviate_user;
```

Create a warehouse for processing data in Snowflake.

```sql
-- Weaviate Warehouse --
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE WEAVIATE_WAREHOUSE WITH
  WAREHOUSE_SIZE='X-SMALL'
  AUTO_SUSPEND = 180
  AUTO_RESUME = true
  INITIALLY_SUSPENDED=true;
```

Create a database, image repository and stages. The image repository will house our container images, and stages will serve as a home for our service specification files, as well as files created and saved on the service.

```sql
-- Weaviate Database --
-- + image repo --
-- + stages --
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS WEAVIATE_DEMO;
USE DATABASE WEAVIATE_DEMO;
CREATE IMAGE REPOSITORY WEAVIATE_DEMO.PUBLIC.WEAVIATE_REPO;
CREATE OR REPLACE STAGE YAML_STAGE;
CREATE OR REPLACE STAGE DATA ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
CREATE OR REPLACE STAGE FILES ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
```

Grant privileges on the databases to the WEAVIATE_ROLE:

```sql
-- Grants for Weaviate Role --
USE ROLE SECURITYADMIN;
GRANT ALL PRIVILEGES ON DATABASE WEAVIATE_DEMO TO WEAVIATE_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA WEAVIATE_DEMO.PUBLIC TO WEAVIATE_ROLE;
GRANT ALL PRIVILEGES ON WAREHOUSE WEAVIATE_WAREHOUSE TO WEAVIATE_ROLE;
GRANT ALL PRIVILEGES ON STAGE WEAVIATE_DEMO.PUBLIC.FILES TO WEAVIATE_ROLE;
```

External access integration that will allow the Jupyter service to access the open internet.

```sql
-- External Access Integration
USE ROLE ACCOUNTADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
CREATE NETWORK RULE allow_all_rule
  TYPE = 'HOST_PORT'
  MODE= 'EGRESS'
  VALUE_LIST = ('0.0.0.0:443','0.0.0.0:80');

CREATE EXTERNAL ACCESS INTEGRATION allow_all_eai
  ALLOWED_NETWORK_RULES=(allow_all_rule)
  ENABLED=TRUE;

GRANT USAGE ON INTEGRATION allow_all_eai TO ROLE SYSADMIN;
```

### 3. Setup compute pools

Create compute pools. We will deploy our services to these compute pools.

```sql
-- Compute Pools --
USE ROLE SYSADMIN;
CREATE COMPUTE POOL IF NOT EXISTS WEAVIATE_COMPUTE_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_S
  AUTO_RESUME = true;
CREATE COMPUTE POOL IF NOT EXISTS TEXT2VEC_COMPUTE_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = GPU_NV_S
  AUTO_RESUME = true;
CREATE COMPUTE POOL IF NOT EXISTS JUPYTER_COMPUTE_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_S
  AUTO_RESUME = true;
```

To configure your own instance, edit the pool names and pool sizes to support your application.

To check if the compute pools are active, run `DESCRIBE COMPUTE POOL <Pool Name>`, or `SHOW COMPUTE POOLS`.

```sql
DESCRIBE COMPUTE POOL WEAVIATE_COMPUTE_POOL;
DESCRIBE COMPUTE POOL TEXT2VEC_COMPUTE_POOL;
DESCRIBE COMPUTE POOL JUPYTER_COMPUTE_POOL;
```

The compute pools are ready for use when they reach the `ACTIVE` or `IDLE` state.

### 4. Build the Docker images

Build the Docker images in your local shell. There are three images:

- The Weaviate image runs the database.
- The `text2vec` image lets you process data without leaving Snowpark.
- The Jupyter image lets you store your notebooks.

The Docker files are in [this repo](../images). You don't need to modify them to run this sample instance. If you need to use non-standard ports or make other changes for your deployment, edit the Dockerfiles before you create the containers. You can run these commands from the root directory of this repository.

```bash
docker build --rm --no-cache --platform linux/amd64 -t weaviate ./images/weaviate
docker build --rm --no-cache --platform linux/amd64 -t jupyter ./images/jupyter
docker build --rm --no-cache --platform linux/amd64 -t text2vec ./images/text2vec
```

Log in to the Docker repository. The Snowpark account name, username, and password are the same as your `snowsql` credentials.

```bash
docker login <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com  -u YOUR_SNOWFLAKE_USERNAME
```

After you login to the Docker repository, tag the images and push them to the repository.

The `docker tag` commands look like this:

```bash
docker tag weaviate <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com/weaviate_demo/public/weaviate_repo/weaviate
docker tag juypter <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com/weaviate_demo/public/weaviate_repo/jupyter
docker tag text2vec <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com/weaviate_demo/public/weaviate_repo/text2vec
```

The `docker push` commands look like this:

```bash
docker push <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com/weaviate_demo/public/weaviate_repo/weaviate
docker push <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com/weaviate_demo/public/weaviate_repo/jupyter
docker push <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com/weaviate_demo/public/weaviate_repo/text2vec
```

### 5. Setup service spec files

SPCS uses `spec files` to configure services. The configuration spec files are in [this repo](../specs).

Download the [spec files](../specs), then edit them to specify an image repository. To configure your own instance, add your deployment's image repository instead of the sample repository. 

For instance, in the `jupyter.yaml` spec, you would update the `image` definition to include your Snowflake Account's information:

```yaml
image: "<SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>.registry.snowflakecomputing.com/weaviate_demo/public/weaviate_repo/jupyter"
```

You will also have to update the `SNOW_ACCOUNT` environment variable in the Jupyter spec with your `SNOW_ACCOUNT: <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>` details:

```yaml
SNOW_ACCOUNT: <SNOWFLAKE_ORG>-<SNOWFLAKE_ACCOUNT>
```

When the files are updated, use the `snowsql` client on your local machine to upload them. 

```sql
PUT file:///path/to/jupyter.yaml @yaml_stage overwrite=true auto_compress=false;
PUT file:///path/to/text2vec.yaml @yaml_stage overwrite=true auto_compress=false;
PUT file:///path/to/weaviate.yaml @yaml_stage overwrite=true auto_compress=false;
```

### 6. Create the services

Use `snowsql` to create a service for each component.

```sql
-- Services --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
CREATE SERVICE WEAVIATE
  IN COMPUTE POOL WEAVIATE_COMPUTE_POOL 
  FROM @YAML_STAGE
  SPEC='weaviate.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1;
CREATE SERVICE JUPYTER
  IN COMPUTE POOL JUPYTER_COMPUTE_POOL 
  FROM @YAML_STAGE
  SPEC='jupyter.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1
  EXTERNAL_ACCESS_INTEGRATIONS=(ALLOW_ALL_EAI);
CREATE SERVICE TEXT2VEC
  IN COMPUTE POOL TEXT2VEC_COMPUTE_POOL 
  FROM @YAML_STAGE
  SPEC='text2vec.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1;
```  

### 7. Grant user permissions

Grant permission to the services to the weaviate_role, to ensure the corresponding weaviate_user has the ability to use these services.

```sql
-- Usage for Weaviate Role --
USE ROLE SECURITYADMIN;
GRANT USAGE ON SERVICE WEAVIATE_DEMO.PUBLIC.JUPYTER TO ROLE WEAVIATE_ROLE;
```

### 8. Log in to the Jupyter Notebook Server

Get the `ingress_url` URL that you use to access the Jupyter notebook server.

```sql
-- Get public Jupyter URL --
USE ROLE SYSADMIN;
SHOW ENDPOINTS IN SERVICE WEAVIATE_DEMO.PUBLIC.JUPYTER;
```

Open the `ingress_url` in a browser. Use the `weaviate_user` credentials to log in. 

### 9. Load data into your Weaviate instance

Follow these steps to create a schema in the Weaviate DB, and load some sample data into your Weaviate instance.

1. Download the Jeopardy sample questions from Weaviate [`here`](https://github.com/weaviate-tutorials/quickstart/blob/main/data/jeopardy_tiny.json). Rename the file as as "**SampleJSON.json**" and save it to your local drive.
1. Upload the file (using the upload button in the upper-right corner) into the Jupyter tree view in your browser.
1. Use the provided notebook (**TestWeaviate.ipynb**) in Jupyter to copy the data into Weaviate.

### 10. Query your data
Using Jupyter Notebooks, you can now query your data and confirm vectors are there.

```python
# run a simple search
response = collection.query.near_text(query="animal",limit=2, include_vector=True)
#confirm vectors exists
for o in response.objects:
    print(o.vector)

#Hybrid search
response = collection.query.hybrid(
    query="animals",
    limit=5
)

for o in response.objects:
    print(o.properties)
```

## Suspend and resume services

To suspend and resume services, run the following code in to the `snowsql` client.

### Suspend services
```sql
alter service WEAVIATE suspend;
alter service TEXT2VEC suspend;
alter service JUPYTER suspend;
```

### Resume services:
```sql
alter service WEAVIATE resume;
alter service TEXT2VEC resume;
alter service JUPYTER resume;
```

## Cleanup and Removal

To remove the services, run the following code in to the `snowsql` client.

```sql
-- Services --
USE ROLE SYSADMIN;
DROP SERVICE WEAVIATE_DEMO.PUBLIC.WEAVIATE;
DROP SERVICE WEAVIATE_DEMO.PUBLIC.JUPYTER;
DROP SERVICE WEAVIATE_DEMO.PUBLIC.TEXT2VEC;

-- Compute Pools --
USE ROLE SYSADMIN;
DROP COMPUTE POOL WEAVIATE_COMPUTE_POOL;
DROP COMPUTE POOL JUPYTER_COMPUTE_POOL;
DROP COMPUTE POOL TEXT2VEC_COMPUTE_POOL;

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
```
