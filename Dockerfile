FROM docker:stable

RUN apk add --update bash

COPY script /script
COPY sysctl.conf /etc/sysctl.conf

ENTRYPOINT ["/script/run-elasticsearch.sh"]
