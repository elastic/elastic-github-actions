FROM docker:stable

RUN apk add --update bash

COPY script /script

ENTRYPOINT ["/run-elasticsearch.sh"]
