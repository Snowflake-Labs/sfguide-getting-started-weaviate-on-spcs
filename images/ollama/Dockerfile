FROM ollama/ollama:0.1.22

# Pull Mistral when building the image
RUN $(ollama serve > output.log 2>&1 &) && sleep 10 && ollama pull mistral && pkill ollama && rm output.log

ENTRYPOINT ["ollama"]
CMD ["serve"]
