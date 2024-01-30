FROM ollama/ollama:0.1.22

# Set the working directory
WORKDIR /workspace/

# For Jupyter only
EXPOSE  8888
RUN apt-get update && apt-get install -y \
    python3-pip

COPY --chmod=777 requirements-snowflake.txt Create_Product_Descriptions.ipynb startup.sh ./ 
# Install the dependencies from the requirements-snowflake.txt file
RUN pip3 install --no-cache-dir --upgrade pip
RUN pip3 install --no-cache-dir -r requirements-snowflake.txt
RUN mkdir /workspace/.local /workspace/.cache && chmod 777 -R Create_Product_Descriptions.ipynb

ENTRYPOINT ["./startup.sh"]
