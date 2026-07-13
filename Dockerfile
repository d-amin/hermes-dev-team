FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl git python3 python3-pip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
ENV PATH="/root/.hermes/bin:${PATH}"

WORKDIR /app
COPY . .

EXPOSE 10000
CMD ["hermes", "serve", "--port", "10000"]
