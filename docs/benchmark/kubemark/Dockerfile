ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG GOLANG_VERSION
ARG KUBE_ROOT
ARG GO_RUNNER_VERSION

FROM localhost:35000/golang:$GOLANG_VERSION AS build
COPY __KUBE_ROOT__ /go/src/
WORKDIR /go/src/$KUBE_ROOT
RUN CGO_ENABLED=0 GOPROXY=https://goproxy.cn,direct go build -ldflags \
    "-X 'k8s.io/kubernetes/vendor/k8s.io/client-go/pkg/version.gitVersion=__VERSION__' \
    -X 'k8s.io/kubernetes/vendor/k8s.io/component-base/version.gitVersion=__VERSION__' \
    -X 'k8s.io/client-go/pkg/version.gitVersion=__VERSION__' \
    -X 'k8s.io/component-base/version.gitVersion=__VERSION__'" \
    -mod=mod -v -o /kubemark ./cmd/kubemark

FROM localhost:35000/wrype/go-runner:$GO_RUNNER_VERSION
COPY --from=build /kubemark /kubemark
