-- Make sure you finished the common setup.sql
-- before running this setup.sql

-- File format --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
create or replace file format my_csv_format 
  type = csv 
  field_delimiter = ',' 
  skip_header = 1 
  null_if = ('NULL', 'null') 
  FIELD_OPTIONALLY_ENCLOSED_BY='"'
  empty_field_as_null = true;

-- Stage --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
CREATE OR REPLACE STAGE REVIEW_DATA ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

USE ROLE SECURITYADMIN;
GRANT ALL PRIVILEGES ON STAGE WEAVIATE_DEMO.PUBLIC.REVIEW_DATA TO WEAVIATE_ROLE;

-- Tables --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE 
    PRODUCT_REVIEWS (REVIEWERID varchar, ASIN varchar, 
    REVIEWERNAME varchar, HELPFUL varchar, 
    REVIEWTEXT varchar, OVERALL varchar, 
    SUMMARY varchar, UNIXREVIEWTIME varchar, REVIEWTIME varchar);

-- Put file into stage --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
PUT file:///path/to/Musical_instruments_reviews.csv @REVIEW_DATA overwrite=true;

-- Copy data into table --
USE ROLE SYSADMIN;
USE DATABASE WEAVIATE_DEMO;
USE SCHEMA PUBLIC;
COPY INTO PRODUCT_REVIEWS FROM @REVIEW_DATA FILE_FORMAT = (format_name = 'my_csv_format' , error_on_column_count_mismatch=false);

-- Confirm data --
USE ROLE SYSADMIN;
SELECT * FROM PRODUCT_REVIEWS; 

-- Grants for Weaviate Role --
USE ROLE SECURITYADMIN;
GRANT SELECT ON TABLE WEAVIATE_DEMO.PUBLIC.PRODUCT_REVIEWS TO ROLE WEAVIATE_ROLE;
