FROM docker:stable

COPY run-elasticsearch.sh /run-elasticsearch.sh

ENTRYPOINT ["/run-elasticsearch.sh"]
