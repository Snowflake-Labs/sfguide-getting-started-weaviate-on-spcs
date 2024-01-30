#!/bin/bash
# Start Jupyter Notebook
jupyter notebook --ip='*' --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password=''

#for running service as container starts
#I do this manually in the example
#/bin/ollama serve
#/bin/ollama run mistral
