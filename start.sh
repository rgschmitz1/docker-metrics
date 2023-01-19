#!/bin/bash
cd $(dirname $0)
# start docker in interactive mode
docker run --rm -it -v $PWD:/data -v /var/run/docker.sock:/var/run/docker.sock docker-metrics
