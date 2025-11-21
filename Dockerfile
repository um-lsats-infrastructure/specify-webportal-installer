# Build it like this:
## docker build --tag webportal-service:improve-build .
# docker build --tag webportal-service:new-birds .

# Run it like this: (Changed second port to 8080, as was done in old custom OpenShift version)
## docker run -p 80:8080 -v /absolute/location/of/your/export.zip:/home/specify/webportal-installer/specify_exports/export.zip webportal-service:improve-build
# docker run -d --name new-birds -p 80:8080 webportal-service:new-birds

FROM public.ecr.aws/ubuntu/ubuntu:24.04

LABEL maintainer="Specify Collections Consortium <github.com/specify>"

COPY fix-permissions /usr/bin/
COPY cgroup-limits /usr/bin/

RUN    chmod +x /usr/bin/fix-permissions \
    && chmod +x /usr/bin/cgroup-limits

RUN    mkdir -p /tmp/src && \
       mkdir -p /usr/libexec/s2i

COPY s2i/ /usr/libexec/s2i/

RUN    chown -R 1001:0 /tmp/src \
    && chmod +rx /usr/libexec/s2i/assemble \
    && chmod +rx /usr/libexec/s2i/run \
    && chmod +rx /usr/libexec/s2i/usage \
    && chown -R 1001:0 /var/lib/nginx


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
        vim\
        openjdk-17-jre-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy application code as the unprivileged 'specify' user
## Changed exposed port to 8081 (As was done in old custom OpenShift version.)
COPY --chown=1001:0 . /home/specify/webportal-installer
WORKDIR /home/specify/webportal-installer
EXPOSE 8081

## Should preobably plan to do config in a configMap and mount it to the container
# Configure nginx (commented out COPY since done above)
COPY webportal-nginx.conf /etc/nginx/sites-available/webportal-nginx.conf
RUN rm /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/webportal-nginx.conf /etc/nginx/sites-enabled/ \
    && service nginx stop

# Redirect nginx logs to Docker stdout/stderr
RUN ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -sf /dev/stdout /var/log/nginx/access.log

USER 1001

RUN   make clean-all && \
      make build-all

CMD ["/usr/libexec/s2i/usage"]
