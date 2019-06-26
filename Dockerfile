FROM          alpine:3.10.0
MAINTAINER    Laur Aliste

ADD cron.template /cron.template
ADD setup.sh /setup.sh
ADD gad.sh /gad
COPY entry.sh /entry.sh
RUN apk add --no-cache curl bind-tools bash && \
    chmod 755 /gad /setup.sh /entry.sh
#RUN /usr/bin/crontab /crontab.txt

CMD ["/entry.sh"]