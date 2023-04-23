# Set the base image
FROM ghcr.io/linuxserver/baseimage-alpine@sha256:bd061febca5ba95b204c8137de27fdfc6443c0e003371710c9e0902fe3a02012

# Set the maintainer
LABEL maintainer="GhostWriters"

# Copy files from host to container
COPY root /

# Install required packages and application dependencies
RUN apk add --no-cache py3-pip && \
    pip3 install --no-cache-dir -r /opt/requirements.txt

# Add a health check command to ensure the container is running correctly
HEALTHCHECK --interval=1m \
    --timeout=3s \
    CMD ps -ef | grep cron || exit 1

# Specify the entrypoint
ENTRYPOINT ["/opt/docker-entrypoint.sh"]
