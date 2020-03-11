<img align="right" width="auto" height="auto" src="https://www.elastic.co/static-res/images/elastic-logo-200.png">

# Elasticsearch Github Action

![Elasticsearch Github Action](https://github.com/elastic/elasticsearch-github-action/workflows/Elasticsearch%20Github%20Action/badge.svg)

This action spins up an Elasticsearch instance that can be accessed and used in your subsequent steps.

## Inputs

| Name        | Required         | Default  | Description  |  
| ------------- |-------------| -----|-----|
| `elasticsearch-version`     | Yes |  | The version of Elasticsearch you need to use, you can use any version present in [docker.elastic.co](https://www.docker.elastic.co/). |

## Usage

You *must* also add the `Configure sysctl limits` step, otherwise Elasticsearch will not be able to boot.

```yml
- name: Configure sysctl limits
  run: |
    sudo swapoff -a
    sudo sysctl -w vm.swappiness=1
    sudo sysctl -w fs.file-max=262144
    sudo sysctl -w vm.max_map_count=262144

- name: Runs Elasticsearch
  uses: elastic/elasticsearch-github-action@master
  with:
    elasticsearch-version: 7.6.0
```

## License

This software is licensed under the [Apache 2 license](./LICENSE).
