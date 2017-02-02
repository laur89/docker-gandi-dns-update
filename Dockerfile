FROM        phusion/baseimage:0.9.19
MAINTAINER    Laur

ENV DEBIAN_FRONTEND=noninteractive

# gandi-automatic-dns script dependencies and system configuration
RUN apt-get update && \
    apt-get install -y --no-install-recommends dnsutils && \
    mkdir -p /etc/my_init.d && \
    update-locale LANG=C.UTF-8

ADD cron.template /cron.template
ADD setup.sh /etc/my_init.d/setup.sh
ADD gandi-automatic-dns/gad /usr/local/sbin/gad

# Clean up for smaller image
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Baseimage init process
ENTRYPOINT ["/sbin/my_init"]
