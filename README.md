# Jupyter Notebook for Snowpark Container Services
This is an example for setting up Jupyter inside Snowpark
Conatiner Services.

This service will mount 2 stages into the container:
* A working directory where you can save your notebooks,
  files, etc. This allows you to save your work in a stage
  so you can pick up where you left off even if the service
  is restarted.
* A directory that will host Python packages that you install
  with `pip install`. This allows you to save installed packages
  even if the service is restarted.

# Setup

## Common Setup
Run the following steps as `ACCOUNTADMIN`.
1. Create a `ROLE` that will be used for Snowpark Container Services administration.
```
CREATE ROLE spcs_role;
GRANT ROLE spcs_role TO ACCOUNTADMIN;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE spcs_role;
```
2. Create a `COMPUTE POOL`.
```
CREATE COMPUTE POOL pool1
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = standard_1;
GRANT USAGE, MONITOR ON COMPUTE POOL pool1 TO ROLE spcs_role;
```
3. Create a `WAREHOUSE` that we'll use in our `SERVICE`.
```
CREATE OR REPLACE WAREHOUSE wh_xs WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 180
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = FALSE;
GRANT ALL ON WAREHOUSE wh_xs TO ROLE spcs_role;
```
4. Create the necessary `SECURITY INTEGRATION` for Snowpark Container Services.
```
CREATE SECURITY INTEGRATION snowservices_ingress_oauth
    TYPE=oauth
    OAUTH_CLIENT=snowservices_ingress
    ENABLED=true;
```

## Project Setup
1. Use the `SPCS_ROLE`
```
USE ROLE spcs_role;
```
2. Create a `DATABASE` and `SCHEMA` for this use. You can, of course use
  an existing `DATABASE` and `SCHEMA`.
```
CREATE DATABASE sandbox;
CREATE SCHEMA spcs;
USE SCHEMA sandbox.spcs;
```
3. Create the `IMAGE REPOSITORY` and `STAGES` we will need. 
  The `PYTHON_PACKAGES` stage will hold the installed packages. The
  `JUPYTER_HOME` stage will hold the Jupyter working directory files.
```
CREATE IMAGE REPOSITORY repo1;
CREATE STAGE python_packages 
    DIRECTORY = ( ENABLE = true ) 
    ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );
CREATE STAGE jupyter_home 
    DIRECTORY = ( ENABLE = true ) 
    ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );
```
4. You will need the repository URL for the `IMAGE REPOSITORY`. Run
  the following command and note the value for `repository_url`.
```
SHOW IMAGE REPOSITORIES;
```

## Build the Docker image and upload to Snowflake
1. In the root directory of this repository, run the following command.
```
bash ./configure.sh
```
  When prompted, enter:
  * the `repository_url` for the Image Repository URL
  * the `WAREHOUSE` name that can be used, e.g., `wh_xs`
  * the `STAGE` name for the Jupyter home/working directory, e.g., `@SANDBOX.SPCS.JUPYTER_HOME`.
  * the `STAGE` name for the Python packages, e.g., `@SANDBOX.SPCS.PYTHON_PACKAGES`.

  This will create a `Makefile` that can be used to build locally and also
  to build for Snowpark Container Services, including pushing the image to
  the specified image repository. It also creates a `jupyter.yaml` file that is
  the Snowpark Container Services specification file for use when creating the `SERVICE`.
2. Build the image, tag it, and push it to Snowflake.
```
make all
```
3. The `make ddl` command will print a sample SQL DDL statement to create
  the `SERVICE`. You will need to modify the `COMPUTE POOL` name from `your_compute_pool`
  to the name of the `COMPUTE POOL` you would like to use. In our case that 
  would be `POOL1`.

## Create the Service and Grant Access
1. Use the `SPCS_ROLE` and the `DATABASE` and `SCHEMA` we created earlier.
```
USE ROLE spcs_role;
USE SCHEMA sandbox.spcs;
```
2. Use the DDL that was produced by `make ddl`, replacing `POOL1` for the 
  `COMPUTE POOL`:
```
CREATE SERVICE jupyter
    IN COMPUTE POOL pool1
    FROM SPECIFICATION $$
spec:
containers:
    - name: jupyter
    image: <YOUR_ACCOUNT>.registry.snowflakecomputing.com/sandbox/spcs/repo1/jupyter_spcs
    env:
        SNOWFLAKE_WAREHOUSE: wh_xs
    volumeMounts:
        - name: jupyterhome
        mountPath: /app
        - name: pythonpath
        mountPath: /usr/local/lib/python3.10/site-packages

endpoints:
    - name: jupyter
    port: 8080
    public: true
volumes:
    - name: pythonpath
    source: "@SANDBOX.SPCS.PYTHON_PACKAGES"
    - name: jupyterhome
    source: "@SANDBOX.SPCS.JUPYTER_HOME"
networkPolicyConfig:
    allowInternetEgress: true
$$;
```
3. See that the service has started by executing `SHOW SERVICES IN COMPUTE POOL pool1` 
  and `SELECT system$get_service_status('jupyter')`.
4. Find the public endpoint for the service by executing `SHOW ENDPOINTS IN SERVICE jupyter`.
5. Grant `USAGE` on the `SERVICE` to other `ROLES` so they can access it: 
  `GRANT USAGE ON SERVICE jupyter TO ROLE some_role`.
  Note that a user needs to have a default `ROLE` _other_ than `ACCOUNTADMIN`,
  `SECURITYADMIN`, or `ORGADMIN` to visit the endpoint for the `SERVICE`.

## Use Jupyter
1. Navigate to the endpoint and authenticate with a user that has access.
2. Notebooks created in the default directory will be synced to the `JUPYTER_HOME` stage.
3. Python packages can be installed by running `pip install <package_name>`, and these
  will be installed in a directory that syncs to the `PYTHON_PACKAGES` stage.
4. You can connect to Snowflake using the service token by leveraging the `spcs_helpers`
  convenience package. You can then use the `Session` object to make queries, etc.
```
from snowflake import spcs_helpers
session = spcs_helpers.session()
```

# Local Testing
Jupyter can be tested running locally. To do that, build the
image for your local machine with `make build_local`.

In order to run the Jupyter in the container, we need to set some 
environment variables in our terminal session before running the 
container. The variables to set are:
* `SNOWFLAKE_ACCOUNT` - the account locator for the Snowflake account
* `SNOWFLAKE_USER` - the Snowflake username to use
* `SNOWFLAKE_PASSWORD` - the password for the Snowflake user
* `SNOWFLAKE_WAREHOUSE` - the warehouse to use
* `SNOWFLAKE_DATABASE` - the database to set as the current database (does not really matter that much what this is set to)
* `SNOWFLAKE_SCHEMA` - the schema in the database to set as the current schema (does not really matter that much what this is set to)

Once those have been set, run the Jupyter container with `make run`. Navigate
to `http://localhost:8080`.