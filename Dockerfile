FROM          alpine:3.12.0
MAINTAINER    Laur Aliste

ADD cron.template setup.sh entry.sh gad.sh   /
RUN apk add --no-cache curl bind-tools bash && \
    chmod 755 /gad.sh /setup.sh /entry.sh
#RUN /usr/bin/crontab /crontab.txt

CMD ["/entry.sh"]
