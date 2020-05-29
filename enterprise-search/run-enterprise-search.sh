#!/bin/bash

set -euxo pipefail

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

docker network create elastic

docker run \
       --rm \
       --env "node.name=es1" \
       --env "cluster.name=docker-elasticsearch" \
       --env "cluster.initial_master_nodes=es1" \
       --env "discovery.seed_hosts=es1" \
       --env "cluster.routing.allocation.disk.threshold_enabled=false" \
       --env "bootstrap.memory_lock=true" \
       --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
       --env "xpack.security.enabled=true" \
       --env "xpack.license.self_generated.type=basic" \
       --env "ELASTIC_PASSWORD=changeme" \
       --ulimit nofile=65536:65536 \
       --ulimit memlock=-1:-1 \
       --publish "9200:9200" \
       --detach \
       --network=elastic \
       --name="es1" \
       docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}

docker run \
  --network elastic \
  --rm \
  appropriate/curl \
  --max-time 120 \
  --retry 120 \
  --retry-delay 1 \
  --retry-connrefused \
  --show-error \
  --silent \
  --user elastic:changeme \
  http://es1:9200

sleep 10

echo "Elasticsearch up and running"

docker run \
       --env "ENT_SEARCH_DEFAULT_PASSWORD=itsnotcloudsearch" \
       --env "ent_search.listen_port=8080" \
       --env "ent_search.external_url=http://enterprise-search:8080" \
       --env "ent_search.auth.source=standard" \
       --env "elasticsearch.host=http://es1:9200" \
       --env "allow_es_settings_modification=true" \
       --env "elasticsearch.username=elastic" \
       --env "elasticsearch.password=changeme" \
       --env "secret_management.encryption_keys=['testtesttest']" \
       --publish "8080:8080" \
       --publish "8081:8081" \
       --name="enterprise-search" \
       --detach \
       --network=elastic \
       --rm \
       docker.elastic.co/enterprise-search/enterprise-search:${STACK_VERSION:?missing revision for enterprise search}

docker run \
       --network elastic \
       --rm \
       appropriate/curl \
       --max-time 600 \
       --retry 120 \
       --retry-delay 5 \
       --retry-connrefused \
       --show-error \
       --silent \
       http://enterprise-search:8080/swiftype-app-version

sleep 10

echo "Enterprise Search is up and running"
