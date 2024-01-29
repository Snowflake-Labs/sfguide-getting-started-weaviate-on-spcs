author: Jon Tuite
id: weaviate-on-spcs
summary: Use SPCS to deploy Weaviate and a vectorizer, then load data and perform a hybrid search on vectors.
categories: Getting-Started
environments: web
status: Published 
feedback link: https://github.com/Snowflake-Labs/sfguide-getting-started-weaviate-on-spcs/issues
tags: Weaviate, Containers, vectors, vectorizer, embeddings, semantic search, hybrid search 

## 1. Log into Snowflake

Download the [SnowSQL](https://docs.snowflake.com/en/user-guide/snowsql) client. Use the SnowSQL client to connect to Snowflake.

```bash  
snowsql -a "YOURINSTANCE" -u "YOURUSER"
```

It is recommended that you use SnowSQL because you will be uploading files from your local machine to your Snowflake account.

## 2. Set up environment

Set up OAUTH integration.

```sql
USE ROLE ACCOUNTADMIN;
CREATE SECURITY INTEGRATION SNOWSERVICES_INGRESS_OAUTH
  TYPE=oauth
  OAUTH_CLIENT=snowservices_ingress
  ENABLED=true;
```

Create a role, and a user, for the Weaviate instance. 

```sql

CREATE ROLE WEAVIATE_ROLE;
CREATE USER weaviate_user
  PASSWORD='weaviate123'
  DEFAULT_ROLE = WEAVIATE_ROLE
  DEFAULT_SECONDARY_ROLES = ('ALL')
  MUST_CHANGE_PASSWORD = FALSE;
GRANT ROLE WEAVIATE_ROLE TO USER weaviate_user;
ALTER USER weaviate_user SET DEFAULT_ROLE = WEAVIATE_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE WEAVIATE_ROLE;
GRANT ALL PRIVILEGES ON STAGE FILES TO WEAVIATE_ROLE;
```

To configure your own instance, edit these fields before you run the SQL code.

- Add a user
- Add a role
- Edit the `PASSWORD` field

Create a database and warehouse to use with Weaviate.

```sql
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE WEAVIATE_WAREHOUSE WITH
  WAREHOUSE_SIZE='X-SMALL'
  AUTO_SUSPEND = 180
  AUTO_RESUME = true
  INITIALLY_SUSPENDED=false;
CREATE DATABASE IF NOT EXISTS WEAVIATE_DB_001;
```

Create an image repository for images

```sql
USE DATABASE WEAVIATE_DB_001;
CREATE IMAGE REPOSITORY WEAVIATE_DB_001.PUBLIC.WEAVIATE_REPO;
```

Grant privileges on the databases to the WEAVIATE_ROLE:

```sql
USE ROLE ACCOUNTADMIN;
grant all PRIVILEGES on database WEAVIATE_DB_001 to WEAVIATE_ROLE;
grant all PRIVILEGES on schema PUBLIC to WEAVIATE_ROLE;
grant all on schema PUBLIC to role WEAVIATE_ROLE;
```

To configure your own instance, edit the database name and repository name before you run the SQL code..

### 3. Setup compute pools

Create compute pools. This code creates compute pools for the sample application. 

```sql
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

To check if the compute pools are active, run `DESCRIBE COMPUTE POOL <Pool Name>`.

```sql
DESCRIBE COMPUTE POOL WEAVIATE_COMPUTE_POOL;
DESCRIBE COMPUTE POOL TEXT2VEC_COMPUTE_POOL;
DESCRIBE COMPUTE POOL JUPYTER_COMPUTE_POOL;
```

The compute pools are ready for use when they reach the `ACTIVE` or `IDLE` state.

### 4. Setup files and stages

Create stages for YAML and Data.    

```sql
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DB_001;
CREATE OR REPLACE STAGE YAML_STAGE;
CREATE OR REPLACE STAGE DATA ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
CREATE OR REPLACE STAGE FILES ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
```

SPCS uses `spec files` to configure services. The configuration spec files are in [this repo](../specs).

Download the [spec files](../specs), then edit them to specify an image repository. To configure your own instance, add your deployment's image repository instead of the sample repository. 

For instance, in the `jupyter.yaml` spec, you would update the `image` definition to include your Snowflake Account's information:

```yaml
      image: "<SNOWFLAKE_ACCOUNT>-<SNOWFLAKE_ORG>.registry.snowflakecomputing.com/<DATABASE>/<SCHEMA>/<IMAGE_REPO>/jupyter"
```

When the files are updated, use the `snowsql` client on your local machine to upload them. 

```sql
PUT file:///path/to/jupyter.yaml @yaml_stage overwrite=true auto_compress=false;
PUT file:///path/to/text2vec.yaml @yaml_stage overwrite=true auto_compress=false;
PUT file:///path/to/weaviate.yaml @yaml_stage overwrite=true auto_compress=false;
```

### 5. Build the Docker images

Exit the `snowsql` client, then build the Docker images in your local shell. There are three images.

- The Weaviate image runs the database.
- The `text2vec` image lets you process data without leaving Snowpark.
- The Jupyter image lets you store your notebooks.

The Docker files are in [this repo](../dockerfiles). You don't need to modify them to run this sample instance. If you need to use non-standard ports or make other changes for your deployment, edit the Dockerfiles before you create the containers.

```bash
docker build --rm --platform linux/amd64 -t weaviate ./dockerfiles/weaviate
docker build --rm --platform linux/amd64 -t jupyter ./dockerfiles/jupyter
docker build --rm --platform linux/amd64 -t text2vec ./dockerfiles/text2vec
```

Log in to the Docker repository. The Snowpark account name, username, and password are the same as your `snowsql` credentials.

```bash
docker login YOUR_SNOWACCOUNT-SNOWORG.registry.snowflakecomputing.com  -u YOUR_SNOWFLAKE_USERNAME
```

After you login to the Docker repository, tag the images and push them to the repository.

The `docker tag` commands look like this:

```bash
docker tag weaviate YOUR_REPOSITORY_URL/weaviate
docker tag juypter YOUR_REPOSITORY_URL/jupyter
docker tag text2vec YOUR_REPOSITORY_URL/text2vec
```

The `docker push` commands look like this:

```bash
docker push x0000000000000-xx00000.registry.snowflakecomputing.com/weaviate_db_001/public/weaviate_repo/weaviate
docker push x0000000000000-xx00000.registry.snowflakecomputing.com/weaviate_db_001/public/weaviate_repo/jupyter
docker push x0000000000000-xx00000.registry.snowflakecomputing.com/weaviate_db_001/public/weaviate_repo/text2vec
```

### 6. Create the services

Use `snowsql` to create a service for each component.

```sql
USE ROLE SYSADMIN;
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
  MAX_INSTANCES=1;

CREATE SERVICE TEXT2VEC
  IN COMPUTE POOL TEXT2VEC_COMPUTE_POOL 
  FROM @YAML_STAGE
  SPEC='text2vec.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1;

```  

### 7. Grant user permissions

Grant permission to the services to the weaviate_role. 

```sql
GRANT USAGE ON SERVICE JUPYTER TO ROLE WEAVIATE_ROLE;
GRANT USAGE ON SERVICE WEAVIATE TO ROLE WEAVIATE_ROLE;
GRANT USAGE ON SERVICE TEXT2VEC TO ROLE WEAVIATE_ROLE;
```

### 8. Log in to the Jupyter Notebook Server

Follow these steps to configure the login for Jupyter Notebooks. 

1. Get the `ingress_url` URL that you use to access the Jupyter notebook server.

```sql
SHOW ENDPOINTS IN SERVICE jupyter;
```

1. Open the `ingress_url` in a browser. Use the `weaviate_user` credentials to log in. 

### 9. Load data into your Weaviate instance

Follow these steps to create a schema, and load some sample data into your Weaviate instance.

1. Download the Jeopardy sample questions from Weaviate [`here`](https://github.com/weaviate-tutorials/quickstart/blob/main/data/jeopardy_tiny.json). Rename the file as as "**SampleJSON.json**" and save it to your local drive.
1. Upload the file (using the upload button in the upper-right corner) into the Jupyter tree view in your browser.
1. Use the provided notebook (**TestWeaviate.ipynb**) to copy the data into Weaviate.


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

DROP USER weaviate_user;
DROP SERVICE WEAVIATE;
DROP SERVICE JUPYTER;
DROP SERVICE TEXT2VEC;
DROP COMPUTE POOL TEXT2VEC_COMPUTE_POOL;
DROP COMPUTE POOL WEAVIATE_COMPUTE_POOL;
DROP COMPUTE POOL JUPYTER_COMPUTE_POOL;
DROP STAGE DATA;
DROP STAGE FILES;
DROP IMAGE REPOSITORY WEAVIATE_DB_001.PUBLIC.WEAVIATE_REPO;
DROP DATABASE WEAVIATE_DB_001;
DROP WAREHOUSE WEAVIATE_WAREHOUSE;
DROP COMPUTE POOL WEAVIATE_CP;


DROP ROLE WEAVIATE_ROLE;
DROP SECURITY INTEGRATION SNOWSERVICES_INGRESS_OAUTH;
```
