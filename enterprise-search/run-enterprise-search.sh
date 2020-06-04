#!/bin/bash

set -euxo pipefail

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

docker network create elastic
docker volume create certs

docker run \
       --rm \
       --volume "$(pwd):/usr/share/elasticsearch/config/certificates" \
       --volume "certs:/certs" \
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
       --network=elastic \
       --name="es1" \
       docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
       bash -c '
         yum install -y -q -e 0 unzip;
         if [[ ! -f /certs/bundle.zip ]]; then
           bin/elasticsearch-certutil cert --silent --pem --in config/certificates/instances.yml -out /certs/bundle.zip;
           unzip /certs/bundle.zip -d /certs;
         fi;
         chown -R 1000:0 /certs
       '

docker run \
      --rm \
      --volume "certs:/usr/share/elasticsearch/config/certificates" \
      --env "node.name=es1" \
      --env "cluster.name=docker-elasticsearch" \
      --env "cluster.initial_master_nodes=es1" \
      --env "discovery.seed_hosts=es1" \
      --env "cluster.routing.allocation.disk.threshold_enabled=false" \
      --env "bootstrap.memory_lock=true" \
      --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
      --env "xpack.security.enabled=true" \
      --env "xpack.license.self_generated.type=basic" \
      --env "xpack.security.authc.api_key.enabled=true" \
      --env "ELASTIC_PASSWORD=changeme" \
      --env "xpack.security.http.ssl.enabled=true" \
      --env "xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certificates/es1/es1.key" \
      --env "xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt" \
      --env "xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certificates/es1/es1.crt" \
      --env "xpack.security.transport.ssl.enabled=true" \
      --env "xpack.security.transport.ssl.verification_mode=certificate" \
      --env "xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt" \
      --env "xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certificates/es1/es1.crt" \
      --env "xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certificates/es1/es1.key" \
      --ulimit nofile=65536:65536 \
      --ulimit memlock=-1:-1 \
      --publish "9200:9200" \
      --network=elastic \
      --detach \
      --name="es1" \
      docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}

docker run \
  --network elastic \
  --rm \
  appropriate/curl \
  --insecure \
  --user elastic:changeme \
  --ipv4 \
  --max-time 120 \
  --retry 120 \
  --retry-delay 1 \
  --retry-connrefused \
  --show-error \
  --silent \
  --user elastic:changeme \
  https://es1:9200

sleep 10

echo "Elasticsearch up and running"

docker run \
       --env "ENT_SEARCH_DEFAULT_PASSWORD=itsnotcloudsearch" \
       --env "ent_search.listen_port=8080" \
       --env "ent_search.external_url=http://enterprise-search:8080" \
       --env "ent_search.auth.source=standard" \
       --env "elasticsearch.host=https://es1:9200" \
       --env "allow_es_settings_modification=true" \
       --env "elasticsearch.username=elastic" \
       --env "elasticsearch.password=changeme" \
       --env "secret_management.encryption_keys=['testtesttest']" \
       --env "elasticsearch.ssl.verify=false" \
       --publish "8080:8080" \
       --publish "8081:8081" \
       --name="enterprise-search" \
       --network=elastic \
       --rm \
       docker.elastic.co/enterprise-search/enterprise-search:${STACK_VERSION:?missing revision for enterprise search}

docker run \
       --network elastic \
       --rm \
       appropriate/curl \
       --ipv4 \
       --max-time 600 \
       --retry 120 \
       --retry-delay 5 \
       --retry-connrefused \
       --show-error \
       --silent \
       http://enterprise-search:8080/swiftype-app-version

sleep 10

echo "Enterprise Search is up and running"
