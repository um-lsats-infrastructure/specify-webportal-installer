# Build it like this:
# docker build --tag webportal-service:improve-build .

# Run it like this:
# docker run -p 80:80 -v /absolute/location/of/your/export.zip:/home/specify/webportal-installer/specify_exports/export.zip webportal-service:improve-build
# docker run -p 80:8080 webportal-service:improve-build

FROM ubuntu:18.04

LABEL maintainer="Specify Collections Consortium <github.com/specify>"

# Get Ubuntu packages
RUN apt-get update && apt-get -y install \
    nginx \
    unzip \
    curl \
    wget \
    python \
    python-lxml \
    make \
    lsof \
    vim \
    default-jre

# Clean Up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 999 specify && \
    useradd -r -u 999 -g specify specify

RUN addgroup specify root

RUN mkdir -p /home/specify/webportal-installer && chown specify.specify -R /home/specify

USER specify

# Get Web Portal
COPY --chown=specify:specify . /home/specify/webportal-installer
WORKDIR /home/specify/webportal-installer

EXPOSE 8081

USER root

# Configure nginx to proxy the Solr requests and serve the static files by copying the provided webportal-nginx.conf to /etc/nginx/sites-available/
RUN install -o root -g root -m644 ./webportal-nginx.conf /etc/nginx/sites-available/

# Disable the default nginx site and enable the portal site
RUN rm /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/webportal-nginx.conf /etc/nginx/sites-enabled/ \
    && service nginx stop

RUN ln -sf /dev/stderr /var/log/nginx/error.log && ln -sf /dev/stdout /var/log/nginx/access.log

# comment user directive as master process is run as user in OpenShift anyhow
RUN sed -i.bak 's/^user/#user/' /etc/nginx/nginx.conf

# Build the Solr app
RUN make clean-all && make build-all

# support running as arbitrary user which belogs to the root group
RUN chmod g+rwx /var/run /var/log/nginx /var/lib/nginx

# Run Solr in foreground
# Wait for Solr to load
# Import data from the .zip file
RUN ./build/bin/solr start -force \
    && sleep 20 \
    && make load-data

COPY docker-boot.sh /boot.sh
RUN chmod g+u /boot.sh

RUN chmod -R g+u /home/specify/webportal-installer/build
#RUN ./build/bin/solr restart

RUN touch /home/specify/test-image.jpg
RUN chmod 777 /home/specify/test-image.jpg
RUN chmod 777 /home/specify
RUN chmod -R 777 /home/specify/webportal-installer

ENTRYPOINT ["/boot.sh"]