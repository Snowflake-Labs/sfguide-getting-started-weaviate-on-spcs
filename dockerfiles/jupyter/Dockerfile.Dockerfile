FROM jupyter/base-notebook:python-3.11

# Install the dependencies from the requirements.txt file
RUN pip install requests weaviate-client snowflake-snowpark-python[pandas]
#upgrade to v4 client for weaviate
RUN pip install --pre -U "weaviate-client==4.*"

# Set the working directory
WORKDIR /workspace/

# Expose Jupyter Notebook port
EXPOSE 8888

# Copy the notebooks directory to the container's /app directory
RUN mkdir /workspace/.local /workspace/.cache && chmod 777 -R /workspace

COPY --chmod=777 TestWeaviate.ipynb ./

# Run Jupyter Notebook on container startup
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]