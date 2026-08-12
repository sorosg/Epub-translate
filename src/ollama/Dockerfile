FROM ollama/ollama:latest
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh