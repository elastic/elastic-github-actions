#!/bin/bash

set -euxo pipefail

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

MAJOR_VERSION=`echo ${STACK_VERSION} | cut -c 1`

docker network create elastic

mkdir -p /es/plugins/
chown -R 1000:1000 /es/

if [[ ! -z $PLUGINS ]]; then
  docker run --rm \
    --network=elastic \
    -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
    --entrypoint=/usr/share/elasticsearch/bin/elasticsearch-plugin \
    docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
    install ${PLUGINS/\\n/ } --batch
fi

for (( node=1; node<=${NODES-1}; node++ ))
do
  port_com=$((9300 + $node - 1))
  UNICAST_HOSTS+="es$node:${port_com},"
done

for (( node=1; node<=${NODES-1}; node++ ))
do
  port=$((PORT + $node - 1))
  port_com=$((9300 + $node - 1))
  if [ "x${MAJOR_VERSION}" == 'x6' ]; then
    docker run \
      --rm \
      --env "node.name=es${node}" \
      --env "cluster.name=docker-elasticsearch" \
      --env "cluster.routing.allocation.disk.threshold_enabled=false" \
      --env "bootstrap.memory_lock=true" \
      --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
      --env "xpack.security.enabled=false" \
      --env "xpack.license.self_generated.type=basic" \
      --env "discovery.zen.ping.unicast.hosts=${UNICAST_HOSTS}" \
      --env "discovery.zen.minimum_master_nodes=${NODES}" \
      --env "http.port=${port}" \
      --ulimit nofile=65536:65536 \
      --ulimit memlock=-1:-1 \
      --publish "${port}:${port}" \
      --publish "${port_com}:${port_com}" \
      --detach \
      --network=elastic \
      --name="es${node}" \
      -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
      docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
  elif [ "x${MAJOR_VERSION}" == 'x7' ]; then
    docker run \
      --rm \
      --env "node.name=es${node}" \
      --env "cluster.name=docker-elasticsearch" \
      --env "cluster.initial_master_nodes=es1" \
      --env "discovery.seed_hosts=es1" \
      --env "cluster.routing.allocation.disk.threshold_enabled=false" \
      --env "bootstrap.memory_lock=true" \
      --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
      --env "xpack.security.enabled=false" \
      --env "xpack.license.self_generated.type=basic" \
      --env "http.port=${port}" \
      --env "action.destructive_requires_name=false" \
      --ulimit nofile=65536:65536 \
      --ulimit memlock=-1:-1 \
      --publish "${port}:${port}" \
      --detach \
      --network=elastic \
      --name="es${node}" \
      -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
      docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
  elif [ "x${MAJOR_VERSION}" == 'x8' ]; then
    if [ "${SECURITY_ENABLED}" == 'true' ]; then
      elasticsearch_password=${elasticsearch_password-'changeme'}
      docker run \
        --rm \
        --env "ELASTIC_PASSWORD=${elasticsearch_password}" \
        --env "xpack.license.self_generated.type=basic" \
        --env "node.name=es${node}" \
        --env "cluster.name=docker-elasticsearch" \
        --env "cluster.initial_master_nodes=es1" \
        --env "discovery.seed_hosts=es1" \
        --env "cluster.routing.allocation.disk.threshold_enabled=false" \
        --env "bootstrap.memory_lock=true" \
        --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
        --env "http.port=${port}" \
        --env "action.destructive_requires_name=false" \
        --ulimit nofile=65536:65536 \
        --ulimit memlock=-1:-1 \
        --publish "${port}:${port}" \
        --network=elastic \
        --name="es${node}" \
        --detach \
        -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
        docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
    else
      docker run \
        --rm \
        --env "xpack.security.enabled=false" \
        --env "node.name=es${node}" \
        --env "cluster.name=docker-elasticsearch" \
        --env "cluster.initial_master_nodes=es1" \
        --env "discovery.seed_hosts=es1" \
        --env "cluster.routing.allocation.disk.threshold_enabled=false" \
        --env "bootstrap.memory_lock=true" \
        --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
        --env "xpack.license.self_generated.type=basic" \
        --env "http.port=${port}" \
        --env "action.destructive_requires_name=false" \
        --ulimit nofile=65536:65536 \
        --ulimit memlock=-1:-1 \
        --publish "${port}:${port}" \
        --network=elastic \
        --name="es${node}" \
        --detach \
        -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
        docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
    fi
  fi
done

if [ "x${MAJOR_VERSION}" == 'x8' ] && [ "${SECURITY_ENABLED}" == 'true' ]; then
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
    -k \
    -u elastic:${elasticsearch_password-'changeme'} \
    https://es1:$PORT
else
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
    http://es1:$PORT
fi

sleep 10

echo "Elasticsearch up and running"
