#!/bin/bash
cd $(dirname $0)
docker build -t biodepot/docker-metrics:0.1__alpine-3.17.1 .
