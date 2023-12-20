FROM python:3.10
EXPOSE 8080
WORKDIR /app
RUN pip install --upgrade pip
RUN pip install jupyter snowflake-connector-python snowflake-snowpark-python pandas numpy datetime
RUN pip3 uninstall oscrypto -y
RUN pip3 install oscrypto@git+https://github.com/wbond/oscrypto.git@d5f3437ed24257895ae1edd9e503cfb352e635a8

# Move existing site-packages to site-packages-orig, create new site-packages,
#   and setup Python to know that
RUN mv /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages-orig
RUN mkdir /usr/local/lib/python3.10/site-packages
RUN mkdir /usr/local/lib/python3.10/sitecustomize
RUN echo "import sys\nsys.path.insert(0, '/usr/local/lib/python3.10/site-packages-orig')\n" > /usr/local/lib/python3.10/sitecustomize/__init__.py

# Copy in SPCS_Helpers
COPY spcs_helpers/src/spcs_helpers /usr/local/lib/python3.10/site-packages-orig/snowflake/spcs_helpers

ENTRYPOINT [ "jupyter", "notebook", "--port", "8080", "--allow-root", "--no-browser", "--NotebookApp.token=''", "--NotebookApp.password=''", "--ip=0.0.0.0" ]
