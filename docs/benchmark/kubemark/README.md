<!-- TOC -->

- [准备跨平台编译环境](#准备跨平台编译环境)
- [编译](#编译)
- [npd](#npd)
  - [镜像制作](#镜像制作)
- [创建虚拟节点](#创建虚拟节点)

<!-- /TOC -->

### 准备跨平台编译环境

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx create --name mybuilder --driver docker-container --bootstrap --use --driver-opt network=host
```

### 编译

https://github.com/kubernetes/kubernetes/releases 下载对应版本的源码并解压

buildx 无法使用本地下载好的镜像，同时 buildx 无法使用系统配置好的代理、加速器，需要单独配置

可以使用本地的 registry 作为缓存，参考 https://github.com/docker/buildx/issues/301

```bash
...
if [[ -z `docker ps | grep builder_registry` ]]; then
    docker run -d --name builder_registry -p 35000:5000 registry:2
fi
...
```

> 机器重启后使用 `docker start builder_registry`，重新拉起容器

目录结构

```bash
.
├── build-kubemark.sh
├── Dockerfile
├── README.md
└── kubernetes-1.24.9
    ├── api
    ├── build
    ├── CHANGELOG
    ├── CHANGELOG.md
    ├── ...
```

编译脚本中需要给改为自己的仓库

```bash
build-kubemark.sh
...
    -t wrype/kubemark:$VERSION --push .
...
```

运行编译脚本

```bash
./build-kubemark.sh ./kubernetes-1.24.9
```

### npd

hollow-node_template.yaml 除了 kubelet、kube-proxy 外，还有个 sidecar 用于监控虚拟节点并输出日志

官方镜像缺少 `linux/arm64` 架构，这里已经重新制作并上传到 `wrype/node-problem-detector`

```yaml
官方
...
      - name: hollow-node-problem-detector
        image: k8s.gcr.io/node-problem-detector/node-problem-detector:v0.8.9
...
修改为
...
      - name: hollow-node-problem-detector
        image: wrype/node-problem-detector:v0.8.9
...
```

#### 镜像制作

直接从 https://github.com/kubernetes/node-problem-detector/releases 下载对应版本的二进制文件

镜像构建的相关文件在 [npd 目录](npd) 中，镜像构建时的目录结构为

```bash.
├── build.sh
├── Dockerfile
├── node-problem-detector-v0.8.9-linux_amd64
│   ├── bin
│   ├── config
│   └── test
├── node-problem-detector-v0.8.9-linux_arm64
│   ├── bin
│   ├── config
│   └── test
```

沿用之前的 builder_registry，手动提交基础镜像

```bash
docker pull k8s.gcr.io/debian-base-arm64:v2.0.0
docker tag k8s.gcr.io/debian-base-arm64:v2.0.0 localhost:35000/k8s.gcr.io/debian-base-arm64:v2.0.0
docker push localhost:35000/k8s.gcr.io/debian-base-arm64:v2.0.0

docker pull k8s.gcr.io/debian-base-amd64:v2.0.0
docker tag k8s.gcr.io/debian-base-amd64:v2.0.0 localhost:35000/k8s.gcr.io/debian-base-amd64:v2.0.0
docker push localhost:35000/k8s.gcr.io/debian-base-amd64:v2.0.0

docker manifest create --insecure localhost:35000/k8s.gcr.io/debian-base:v2.0.0 localhost:35000/k8s.gcr.io/debian-base-amd64:v2.0.0 localhost:35000/k8s.gcr.io/debian-base-arm64:v2.0.0
# 源镜像标记为 amd64 架构，这里修改为 arm64架构
docker manifest annotate localhost:35000/k8s.gcr.io/debian-base:v2.0.0 localhost:35000/k8s.gcr.io/debian-base-arm64:v2.0.0 --arch arm64
docker manifest push --insecure localhost:35000/k8s.gcr.io/debian-base:v2.0.0
```

[npd/Dockerfile](npd/Dockerfile) 基于 https://github.com/kubernetes/node-problem-detector/blob/v0.8.9/Dockerfile 修改

构建时直接运行 `build.sh` 即可，需要关注的是程序版本以及构建完成后推送的仓库

```bash
# build-kubemark.sh
...
VERSION=v0.8.9
...
    -t wrype/node-problem-detector:$VERSION --push .
...
```

### 创建虚拟节点

[kernel-monitor.json](kernel-monitor.json) 从 https://github.com/kubernetes/kubernetes/blob/v1.24.9/test/kubemark/resources/kernel-monitor.json 获取

```bash
kubectl create ns kubemark
kubectl create secret generic kubeconfig --type=Opaque -n kubemark --from-file=kubelet.kubeconfig=/root/.kube/config --from-file=kubeproxy.kubeconfig=/root/.kube/config --from-file=npd.kubeconfig=/root/.kube/config
kubectl create cm node-configmap -n kubemark --from-file=kernel.monitor=./kernel-monitor.json
```

这里使用 k8s 1.24.9 版本来测试，`wrype/kubemark` 仓库中已经提交 v1.24.9 版本，可以直接拉取

[hollow-node_template.yaml](hollow-node_template.yaml) 基于 `kubernetes-1.24.9/test/kubemark/resources/hollow-node_template.yaml` 修改，另外需要修改相关变量

| 变量说明          |              |
| ----------------- | ------------ |
| `{{numreplicas}}` | 虚拟节点数量 |
| `{{master_ip}}`   | apiserver ip |

```bash
kubectl apply -n kubemark -f hollow-node_template.yaml
```

kubemark 的相关日志在宿主机 `/var/log` 目录下的 kubelet-hollow-node*、kubeproxy-hollow-node*、npd-hollow-node*