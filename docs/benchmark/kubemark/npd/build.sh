#!/usr/bin/env bash

VERSION=v0.8.9
find node-problem-detector-$VERSION-*/bin/* | xargs chmod +x
docker buildx build \
    --build-arg=VERSION=${VERSION} \
    --platform linux/amd64,linux/arm64 \
    --network=host \
    -t wrype/node-problem-detector:$VERSION --push .