#!/bin/bash
set -euxo pipefail

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

MAJOR_VERSION=`echo ${STACK_VERSION} | cut -c 1`
PLUGINS=${PLUGINS:-}
docker network inspect elastic >/dev/null 2>&1 || docker network create elastic
mkdir -p /es/
touch /es/elasticsearch-plugins.yml
chown -R 1000:1000 /es/

if [[ ! -z $PLUGINS ]]; then
  # Testing https://www.elastic.co/guide/en/elasticsearch/plugins/current/manage-plugins-using-configuration-file.htlm
  echo 'plugins:' > /es/elasticsearch-plugins.yml
  for p in ${PLUGINS[@]}
  do
    echo "  - id: $p" >> /es/elasticsearch-plugins.yml
  done
fi

for (( node=1; node<=${NODES-1}; node++ ))
do
  port_com=$((9300 + $node - 1))
  UNICAST_HOSTS+="es$node:${port_com},"
done

for (( node=1; node<=${NODES-1}; node++ ))
do
  port=$((PORT + $node - 1))
  port_com=$(($PORT + $node - 1))
  # Common parameters
  environment=($(cat <<-END
    --rm
    --env node.name=es${node}
    --env cluster.name=docker-elasticsearch
    --env cluster.routing.allocation.disk.threshold_enabled=false
    --env bootstrap.memory_lock=true
    --ulimit nofile=65536:65536
    --ulimit memlock=-1:-1
    --publish ${port}:${port}
    --env http.port=${port}
    --env xpack.license.self_generated.type=${LICENSE}
END
))

  # Per major version parameter
  if [ "x${MAJOR_VERSION}" == 'x6' ]; then
    environment+=($(cat <<-END
           --env discovery.zen.ping.unicast.hosts=${UNICAST_HOSTS}
           --env discovery.zen.minimum_master_nodes=${NODES}
           --publish ${port_com}:${port_com}
END
))
  elif [ "x${MAJOR_VERSION}" == 'x8' ]; then
    if [ "${SECURITY_ENABLED}" == 'true' ]; then
      elasticsearch_password=${elasticsearch_password-'changeme'}
      environment+=' --env ELASTIC_PASSWORD=${elasticsearch_password}'
    else
      environment+=($(cat <<-END
          --env xpack.security.enabled=false
END
))
    fi
  fi

  # If plugins
  if [[ ! -z $PLUGINS ]]; then
    environment+=($(cat <<-END
      -v /es/elasticsearch-plugins.yml:/usr/share/elasticsearch/config/elasticsearch-plugins.yml
END
))
  fi

  if [ "x${MAJOR_VERSION}" != 'x6' ]; then
  environment+=($(cat <<-END
    --env cluster.initial_master_nodes=es1
    --env action.destructive_requires_name=false
    --env discovery.seed_hosts=es1
END
))
  fi
  # Final parameters
  environment+=($(cat <<-END
        --detach
        --network=elastic
        --name=es${node}
        --rm
END
))
  docker run --env ES_JAVA_OPTS='-Xms1g -Xmx1g' ${environment[@]} "docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}"
done

# Run curl to check if Elasticsearch is up
if [ "x${MAJOR_VERSION}" == 'x8' ] && [ "${SECURITY_ENABLED}" == 'true' ]; then
  docker run --network elastic --rm appropriate/curl --max-time 120 --retry 120 --retry-delay 1 \
  --retry-connrefused --show-error --silent -k -u elastic:${elasticsearch_password-'changeme'} \
  https://es1:$PORT
else
  docker run --network elastic --rm appropriate/curl --max-time 120 --retry 120 --retry-delay 1 \
  --retry-connrefused --show-error --silent http://es1:$PORT
fi

sleep 10
echo "Elasticsearch up and running"
