#!/usr/bin/env bash

KUBE_ROOT=$1
source ${KUBE_ROOT}/test/images/Makefile >/dev/null 2>&1
VERSION=$(basename $KUBE_ROOT)
VERSION="v${VERSION#*'kubernetes-'}"
GO_RUNNER_VERSION=`grep FROM ${KUBE_ROOT}/cluster/images/kubemark/Dockerfile | cut -d : -f 2`

if [[ -z `docker ps | grep builder_registry` ]]; then
    docker run -d --name builder_registry -p 35000:5000 registry:2
fi

if [[ -z `docker manifest inspect localhost:35000/wrype/go-runner:$GO_RUNNER_VERSION` ]]; then
    docker pull wrype/go-runner-linux-amd64:$GO_RUNNER_VERSION
    docker tag wrype/go-runner-linux-amd64:$GO_RUNNER_VERSION localhost:35000/wrype/go-runner-linux-amd64:$GO_RUNNER_VERSION
    docker push localhost:35000/wrype/go-runner-linux-amd64:$GO_RUNNER_VERSION

    docker pull wrype/go-runner-linux-arm64:$GO_RUNNER_VERSION
    docker tag wrype/go-runner-linux-arm64:$GO_RUNNER_VERSION localhost:35000/wrype/go-runner-linux-arm64:$GO_RUNNER_VERSION
    docker push localhost:35000/wrype/go-runner-linux-arm64:$GO_RUNNER_VERSION

    docker manifest create --insecure localhost:35000/wrype/go-runner:$GO_RUNNER_VERSION localhost:35000/wrype/go-runner-linux-amd64:$GO_RUNNER_VERSION localhost:35000/wrype/go-runner-linux-arm64:$GO_RUNNER_VERSION
    docker manifest push --insecure localhost:35000/wrype/go-runner:$GO_RUNNER_VERSION
fi

if [[ -z `docker manifest inspect localhost:35000/golang:$GOLANG_VERSION` ]]; then
    docker pull --platform linux/arm64 golang:$GOLANG_VERSION
    docker tag golang:$GOLANG_VERSION localhost:35000/golang-linux-arm64:$GOLANG_VERSION
    docker push localhost:35000/golang-linux-arm64:$GOLANG_VERSION

    docker pull --platform linux/amd64 golang:$GOLANG_VERSION
    docker tag golang:$GOLANG_VERSION localhost:35000/golang-linux-amd64:$GOLANG_VERSION
    docker push localhost:35000/golang-linux-amd64:$GOLANG_VERSION

    docker manifest create --insecure localhost:35000/golang:$GOLANG_VERSION localhost:35000/golang-linux-amd64:$GOLANG_VERSION localhost:35000/golang-linux-arm64:$GOLANG_VERSION
    docker manifest push --insecure localhost:35000/golang:$GOLANG_VERSION
fi

docker buildx build \
    --build-arg=GOLANG_VERSION=${GOLANG_VERSION} \
    --build-arg=KUBE_ROOT=`basename ${KUBE_ROOT}` \
    --build-arg=GO_RUNNER_VERSION=${GO_RUNNER_VERSION} \
    --platform linux/amd64,linux/arm64 \
    --build-arg=VERSION=${VERSION} \
    --network=host \
    -t wrype/kubemark:$VERSION --push .
