# Weaviate on SPCS
Snowflake provides a hosted solution, [Snowpark Container Services (SPCS)](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview), that runs containers inside the Snowflake ecosystem. The code in this repository deploys Weaviate into SPCS, demonstrating how to run Weaviate in Snowpark. To configure your own SPCS instance, you will need to change the database name, warehouse name, image repository name, and other example values to match your deployment.

In this repository are two guides:

1. [Weaviate on SPCS](guides/weaviate-on-spcs.md) - Deploy a Weaviate vector database and a Jupyter notebook, then interact with Weaviate.

2. [Weaviate Generative Feedback Loop](guides/weaviate-generative-feedback-loop.md) - Deploy a Jupyter notebook on GPUs to summarize instrument reviews using Ollama and Mistral, then load that data into Weaviate and use semantic search to find relevant results.
