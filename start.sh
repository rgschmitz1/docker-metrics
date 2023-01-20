#!/bin/bash
cd $(dirname $0)
# start docker in interactive mode
docker run --rm -it -v $PWD:/data -v /var/run/docker.sock:/var/run/docker.sock biodepot/docker-metrics:0.1__alpine-3.17.1
