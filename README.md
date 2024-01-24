---
title: Snowpark Container Services (SPCS)
sidebar_position: 20
image: og/docs/installation.jpg
# tags: ['installation', 'Snowpark', 'SPCS']
---

Snowflake provides a hosted solution, [Snowpark Container Services (SPCS)](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview), that runs containers inside the Snowflake ecosystem. To configure a Weaviate instance that runs in SPCS, follow the steps on this page.

The code in this guide configures a sample SPCS instance. The sample instance demonstrates how to run Weaviate in Snowpark. To configure your own SPCS instance, change the database name, warehouse name, image repository name, and other example values to match your deployment.


## 1. Log into Snowflake

Download the [SnowSQL](https://docs.snowflake.com/en/user-guide/snowsql) client. Use the SnowSQL client to connect to Snowflake.

```bash  
snowsql -a "YOURINSTANCE" -u "YOURUSER"
```

## 2. Setup a `user` and a `role`

Create a role, and a user, for the Weaviate instance. 

Run this code to create the sample instance.

```sql
USE ROLE ACCOUNTADMIN;
CREATE SECURITY INTEGRATION SNOWSERVICES_INGRESS_OAUTH
  TYPE=oauth
  OAUTH_CLIENT=snowservices_ingress
  ENABLED=true;
CREATE ROLE WEAVIATE_ROLE;
CREATE USER weaviate_user
  PASSWORD='weaviate123'
  DEFAULT_ROLE = WEAVIATE_ROLE
  DEFAULT_SECONDARY_ROLES = ('ALL')
  MUST_CHANGE_PASSWORD = FALSE;
GRANT ROLE WEAVIATE_ROLE TO USER weaviate_user;
ALTER USER weaviate_user SET DEFAULT_ROLE = WEAVIATE_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE WEAVIATE_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE SYSADMIN;
GRANT ALL PRIVILEGES ON STAGE FILES TO WEAVIATE_ROLE;
```

To configure your own instance, edit these fields before you run the SQL code.

- Add a user
- Add a role
- Edit the `PASSWORD` field
 
### 3. Create a database and a warehouse

Create a database and warehouse to use with Weaviate.

```sql
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE WEAVIATE_WAREHOUSE WITH
  WAREHOUSE_SIZE='X-SMALL'
  AUTO_SUSPEND = 180
  AUTO_RESUME = true
  INITIALLY_SUSPENDED=false;
CREATE DATABASE IF NOT EXISTS WEAVIATE_DB_001;
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

### 4. Setup compute pools

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

### 5. Setup files and stages

Create stages for YAML and Data.    

```sql
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DB_001;
CREATE OR REPLACE STAGE YAML_STAGE;
CREATE OR REPLACE STAGE DATA ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
CREATE OR REPLACE STAGE FILES ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
```

SPCS uses `spec files` to configure services. The configuration spec files are in [this repo](https://github.com/Snowflake-Labs/sfguide-getting-started-weaviate-on-spcs). 

Download the spec files, then edit them to specify an image repository. To configure your own instance, add your deployment's image repository instead of the sample repository.

```bash
"SNOWACCOUNT-SNOWORG.registry.snowflakecomputing.com/DATABASE/SCHEMA/weaviate_repo/weaviate"
"SNOWACCOUNT-SNOWORG.registry.snowflakecomputing.com/DATABASE/SCHEMA/weaviate_repo/text2vec"
"SNOWACCOUNT-SNOWORG.registry.snowflakecomputing.com/DATABASE/SCHEMA/weaviate_repo/jupyter"
``` 
When the files are updated, use the `snowsql` client to upload them. 

```sql
PUT file:///path/to/spec-jupyter.yaml @yaml_stage overwrite=true auto_compress=false;
PUT file:///path/to/spec-text2vec.yaml @yaml_stage overwrite=true auto_compress=false;
PUT file:///path/to/spec-weaviate.yaml @yaml_stage overwrite=true auto_compress=false;
```

### 6 Build the Docker images

Exit the `snowsql` client, then build the Docker images in your local shell. There are three images.

- The Weaviate image runs the database.
- The `text2vec` image lets you process data without leaving Snowpark.
- The Jupyter image lets you store your notebooks.

The Docker files are in [this repo](https://github.com/Snowflake-Labs/sfguide-getting-started-weaviate-on-spcs/tree/main/dockerfiles). You don't need to modify them to run this sample instance. If you need to use non-standard ports or make other changes for your deployment, edit the Dockerfiles before you create the containers.

```bash
docker build --rm --platform linux/amd64 -t weaviate -f /path/to/dockerfiles/weaviate.Dockerfile .
docker build --rm --platform linux/amd64 -t jupyter -f /path/to/dockerfiles/jupyter.Dockerfile .
docker build --rm --platform linux/amd64 -t text2vec -f /path/to/dockerfiles/text2vec.Dockerfile .
```

Log in to the Docker repository. The Snowpark account name, username, and password are the same as your `snowsql` credentials.

```bash
docker login YOUR_SNOWACCOUNT-SNOWORG.registry.snowflakecomputing.com/THE_REPO_YOU_CREATED_ABOVE  -u YOUR_SNOWFLAKE_USERNAME
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

### 7. Create the services

Use `snowsql` to create a service for each component.

```sql
USE ROLE SYSADMIN;
CREATE SERVICE WEAVIATE
  IN COMPUTE POOL WEAVIATE_COMPUTE_POOL 
  FROM @YAML_STAGE
  SPEC='spec-weaviate.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1;

CREATE SERVICE JUPYTER
  IN COMPUTE POOL JUPYTER_COMPUTE_POOL 
  FROM @YAML_STAGE
  SPEC='spec-jupyter.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1;

CREATE SERVICE TEXT2VEC
  IN COMPUTE POOL TEXT2VEC_COMPUTE_POOL 
  FROM @YAML_STAGE
  SPEC='spec-text2vec.yaml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1;

```  

### 8. Grant user permissions

Grant permission to the services to the weaviate_role. 

```sql
GRANT USAGE ON SERVICE JUPYTER TO ROLE WEAVIATE_ROLE;
GRANT USAGE ON SERVICE WEAVIATE TO ROLE WEAVIATE_ROLE;
GRANT USAGE ON SERVICE TEXT2VEC TO ROLE WEAVIATE_ROLE;
```

### 9. Configure the Jupyter Notebook login

Follow these steps to configure the login for Jupyter Notebooks. 

1. Load the logs from the jupyter endpoint.

   ```sql
   CALL SYSTEM$GET_SERVICE_LOGS('WEAVIATE_DB_001.PUBLIC.JUPYTER', '0', 'jupyter');
   ```

   Near the end of the log, there are two URLs like this:

   ```
   http://statefulset-0:8888/tree?token=abcd90991a280794f1f1ce0281234e96e877674aa0399999                                                                                
   
   http://127.0.0.1:8888/tree?token=abcd90991a280794f1f1ce0281234e96e877674aa0399999  
   ```

   Save the token, `abcd90991a280794f1f1ce0281234e96e877674aa0399999`.

1. Get the `ingress_url` URL that you use to access the Jupyter notebook server.

   ```sql
   SHOW ENDPOINTS IN SERVICE jupyter;
   ```

1. Open the `ingress_url` in a browser. Use the `weaviate_user` credentials to log in. 
1. Use the token from the logs to set a password.

### 10. Load data into your Weaviate instance

Follow these steps to create a schema, and load some sample data into your Weaviate instance.

1. Download the [`SampleJSON.json`](https://github.com/Snowflake-Labs/sfguide-getting-started-weaviate-on-spcs/blob/main/sample-data/SampleJSON.json) file to your desktop.
1. Drag the file into the Jupyter tree view in your browser.
1. Copy the code for the Weaviate Python client into a Jupyter notebook and run it.
 
```python

import weaviate
import weaviate.classes as wvc
import json
import os

print("Connecting...")

client = weaviate.connect_to_custom(
    http_host="weaviate",
    http_port="8080",
    http_secure=False,
    grpc_host="weaviate",
    grpc_port="50051",
    grpc_secure=False
)

print("Success!")

#Create the Questions collection
collection = client.collections.create(
    name="Questions",
    vectorizer_config=wvc.Configure.Vectorizer.text2vec_transformers(),
    properties=[
        wvc.Property(
            name="answer",
            data_type=wvc.DataType.TEXT
        ),
         wvc.Property(
            name="question",
            data_type=wvc.DataType.TEXT
        ),
         wvc.Property(
            name="category",
            data_type=wvc.DataType.TEXT
        )
    ]
)

print("Collection Created!")

# Import all Questions in batches
items_to_insert = []
with open("SampleJSON.json") as file:
 data = json.load(file)

for i, d in enumerate(data):
   new_item = {
       "answer": d["Answer"],
       "question": d["Question"],
       "category": d["Category"],
   }
   items_to_insert.append(new_item)
   # Insert every 100 items
   if(len(items_to_insert) == 100):
       collection.data.insert_many(items_to_insert)
       items_to_insert.clear()

# Insert remaining items
if(len(items_to_insert) > 0):
   collection.data.insert_many(items_to_insert)

print("Data inserted into Weaviate!")
```

### 11. Query your data

To query your data, run these queries in the a Jupyter notebook.

```python
import weaviate
import json
import os

client = weaviate.connect_to_custom(
    http_host="weaviate",
    http_port="8080",
    http_secure=False,
    grpc_host="weaviate",
    grpc_port="50051",
    grpc_secure=False
)

collection = client.collections.get("Questions")

# run a simple search
response = collection.query.near_text(query="animal",limit=2, include_vector=True)
#confirm vectors exist
for o in response.objects:
    print(o.vector)

client.close()
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
