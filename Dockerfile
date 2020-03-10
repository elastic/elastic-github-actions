FROM docker:stable

RUN apk add --update bash

COPY script script

ENTRYPOINT ["./script/run-elasticsearch.sh"]
