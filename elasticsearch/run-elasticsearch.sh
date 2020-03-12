#!/bin/bash

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

# docker network create elastic

docker run \
  --rm \
  --env "node.name=es1" \
  --env "cluster.name=docker-elasticsearch" \
  --env "cluster.initial_master_nodes=es1" \
  --env "discovery.seed_hosts=es1" \
  --env "cluster.routing.allocation.disk.threshold_enabled=false" \
  --env "bootstrap.memory_lock=true" \
  --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
  --env "xpack.security.enabled=false" \
  --env "xpack.license.self_generated.type=basic" \
  --ulimit nofile=65536:65536 \
  --ulimit memlock=-1:-1 \
  --publish 9200:9200 \
  --detach=false \
  --network=elastic \
  --name=elasticsearch \
  docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
