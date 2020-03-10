FROM alpine:3

RUN apk add --update bash

COPY script /script

ENTRYPOINT ["./script/run-elasticsearch.sh"]
