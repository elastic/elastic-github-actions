FROM docker:stable

RUN apk add --update bash

# RUN echo "" >> etc/sysctl.d/00-alpine.conf
# RUN echo "vm.max_map_count=262144" >> etc/sysctl.d/00-alpine.conf

COPY script /script
COPY sysctl.conf /etc/sysctl.conf

# ENTRYPOINT ["/script/run-elasticsearch.sh"]
