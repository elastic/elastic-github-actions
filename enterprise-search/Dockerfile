FROM docker:stable

RUN apk add --update bash

COPY run-enterprise-search.sh /run-enterprise-search.sh

ENTRYPOINT ["/run-enterprise-search.sh"]
