FROM          alpine:3.12
MAINTAINER    Laur Aliste

ADD files/*   /
RUN apk add --no-cache curl bind-tools bash && \
    chmod 755 /gad.sh /setup.sh /entry.sh
#RUN /usr/bin/crontab /crontab.txt

CMD ["/entry.sh"]
