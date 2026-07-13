FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl git python3 python3-pip python3-yaml ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
ENV PATH="/root/.hermes/bin:${PATH}"

RUN find / -maxdepth 6 -type d -name "hermes-agent" 2>/dev/null || true

WORKDIR /app
COPY . .
RUN chmod +x entrypoint.sh

EXPOSE 10000
CMD ["./entrypoint.sh"]