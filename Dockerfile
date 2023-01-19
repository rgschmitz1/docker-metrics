FROM alpine:latest AS builder
RUN apk add --update docker

FROM alpine:latest
COPY --from=builder /usr/bin/docker /usr/bin/docker
COPY docker-metrics.sh /usr/local/bin
