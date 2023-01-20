FROM alpine:3.17.1
RUN apk add --no-cache docker-cli jq
COPY docker-metrics.sh /usr/local/bin
