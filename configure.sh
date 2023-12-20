#!/bin/bash

# Prompt user for input
read -p "What is the image repository URL (SHOW IMAGE REPOSITORIES IN SCHEMA)? " repository_url
read -p "What warehouse can Jupyter use? " warehouse
read -p "What is the stage location for your Jupyter home/working directory? " jupyterhome_stage
read -p "What is the stage location for the Python packages? " pythonpath_stage

# Paths to the files
makefile="./Makefile"
jupyter_yaml="./jupyter.yaml"

# Copy files
cp $makefile.template $makefile
cp $jupyter_yaml.template $jupyter_yaml

# Replace placeholders in Makefile file using | as delimiter
sed -i "" "s|<<repository_url>>|$repository_url|g" $makefile

# Replace placeholders in Streamlit file using | as delimiter
sed -i "" "s|<<repository_url>>|$repository_url|g" $jupyter_yaml
sed -i "" "s|<<warehouse_name>>|$warehouse|g" $jupyter_yaml
sed -i "" "s|<<pythonpath_stage>>|$pythonpath_stage|g" $jupyter_yaml
sed -i "" "s|<<jupyterhome_stage>>|$jupyterhome_stage|g" $jupyter_yaml

echo "Placeholder values have been replaced!"
