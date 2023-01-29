ARG GOLANG_VERSION
ARG GO_RUNNER_VERSION

FROM localhost:35000/golang:$GOLANG_VERSION AS build
ARG KUBE_ROOT
ARG VERSION
COPY $KUBE_ROOT /go/src/$KUBE_ROOT
WORKDIR /go/src/$KUBE_ROOT
RUN CGO_ENABLED=0 GOPROXY=https://goproxy.cn,direct go build -ldflags \
    "-X 'k8s.io/kubernetes/vendor/k8s.io/client-go/pkg/version.gitVersion=${VERSION}' \
    -X 'k8s.io/kubernetes/vendor/k8s.io/component-base/version.gitVersion=${VERSION}' \
    -X 'k8s.io/client-go/pkg/version.gitVersion=${VERSION}' \
    -X 'k8s.io/component-base/version.gitVersion=${VERSION}'" \
    -mod=mod -v -o /kubemark ./cmd/kubemark

FROM localhost:35000/wrype/go-runner:$GO_RUNNER_VERSION
COPY --from=build /kubemark /kubemark
