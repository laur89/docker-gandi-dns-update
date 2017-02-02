FROM        phusion/baseimage
MAINTAINER    Laur

ENV DEBIAN_FRONTEND=noninteractive

# Seafile dependencies and system configuration
RUN apt-get update && \
    apt-get install -y dnsutils && \
    update-locale LANG=C.UTF-8

ADD gandi-automatic-dns/gad /usr/local/sbin/gad

# Clean up for smaller image
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Baseimage init process
ENTRYPOINT ["/sbin/my_init"]
