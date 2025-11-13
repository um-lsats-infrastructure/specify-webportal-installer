# Build it like this:
# docker build --tag webportal-service:improve-build .

# Run it like this: (Changed second port to 8080, as was done in old custom OpenShift version)
# docker run -p 80:8080 -v /absolute/location/of/your/export.zip:/home/specify/webportal-installer/specify_exports/export.zip webportal-service:improve-build

FROM ubuntu:24.04

LABEL maintainer="Specify Collections Consortium <github.com/specify>"

# Install system packages
RUN apt-get update && apt-get -y install \
        nginx \
        unzip \
        curl \
        wget \
        python3 \
        python3-lxml \
        make \
        lsof \
        openjdk-17-jre-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create 'specify' group and user if they don't already exist
## Added group GID and user UID 999, as was done in old custom OpenShift version.
RUN groupadd -g 999 specify || true \
 && useradd -r -u 999 -g specify specify || true

# Create application directory and set ownership
RUN mkdir -p /home/specify/webportal-installer \
    && chown specify:specify -R /home/specify

# Copy application code as the unprivileged 'specify' user
## Changed exposed port to 8081 (As was done in old custom OpenShift version.)
USER specify
COPY --chown=specify:specify . /home/specify/webportal-installer
WORKDIR /home/specify/webportal-installer
EXPOSE 8081

# Switch back to root for system configuration
USER root

# Configure nginx
COPY webportal-nginx.conf /etc/nginx/sites-available/webportal-nginx.conf
RUN rm /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/webportal-nginx.conf /etc/nginx/sites-enabled/ \
    && service nginx stop

# Redirect nginx logs to Docker stdout/stderr
RUN ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -sf /dev/stdout /var/log/nginx/access.log

## (Added from old custom OpenShift version) comment user directive as master process is run as user in OpenShift anyhow
RUN sed -i.bak 's/^user/#user/' /etc/nginx/nginx.conf

# Default command:
# 1. Clean & build your Solr-based portal
# 2. Start Solr and wait 20s
# 3. Import CSV into Solr
# 4. Launch nginx in foreground
CMD ["sh","-c", "\
    make clean-all && \
    make build-all && \
    ./build/bin/solr start -force && \
    sleep 20 && \
    make load-data || true && \
    nginx -g 'daemon off;' \
"]

## (Added from old custom OpenShift version)
# support running as arbitrary user which belogs to the root group
RUN chmod g+rwx /var/run /var/log/nginx /var/lib/nginx

COPY docker-boot.sh /boot.sh
RUN chmod g+u /boot.sh

RUN chmod -R g+u /home/specify/webportal-installer/build
#RUN ./build/bin/solr restart

RUN touch /home/specify/test-image.jpg
RUN chmod 777 /home/specify/test-image.jpg
RUN chmod 777 /home/specify
RUN chmod -R 777 /home/specify/webportal-installer

ENTRYPOINT ["/boot.sh"]
