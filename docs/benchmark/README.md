<!-- TOC -->

- [部署虚拟节点](#部署虚拟节点)
- [clusterloader](#clusterloader)
  - [Grafana 浏览压测数据](#grafana-浏览压测数据)
- [附录](#附录)
  - [kubemark 镜像列表](#kubemark-镜像列表)
  - [clusterloader 镜像列表](#clusterloader-镜像列表)
  - [参考文档](#参考文档)

<!-- /TOC -->

## 部署虚拟节点

```
kubectl create ns kubemark

kubectl create secret generic kubeconfig --type=Opaque -n kubemark --from-file=kubelet.kubeconfig=/root/.kube/config --from-file=kubeproxy.kubeconfig=/root/.kube/config --from-file=npd.kubeconfig=/root/.kube/config

kubectl create cm node-configmap -n kubemark --from-file=kernel.monitor=./kernel-monitor.json

kubectl apply -n kubemark -f hollow-node_template.yaml
```

详见 [kubemark](./kubemark/README.md)

## clusterloader

使用 https://github.com/wrype/perf-tests 的 `kubeasz-k8s1.24-tester` 分支，基于 master 分支修改，做了以下改动：
- 镜像修改，适配 arm64 架构
- 修复 Prometheus 访问 apiserver 错误，修复 Grafana 调度问题
- 优化访问方式，添加 NodePort

测试时需要自己编译二进制文件，并且将 clusterloader2 整个目录打包上传到测试服务器
```bash
# windows powershell 编译
cd ./clusterloader2
$env:GOOS="linux"
$env:CGO_ENABLED=0
$env:GOARCH="arm64"
go build -v -o clusterloader ./cmd
```

基准测试只能使用 `perf-tests` 中的 prometheus，kubeasz 部署时需要把 `config.yml` 中的 `prom_install` 设置为 no
> 参考 https://github.com/kubernetes/perf-tests/issues/1057

```bash
GCE_SSH_KEY=id_rsa CL2_PROMETHEUS_NODE_SELECTOR='kubernetes.io/role: node' \
./clusterloader --kubeconfig=/root/.kube/config \
--provider=kubemark --provider-configs=ROOT_KUBECONFIG=/root/.kube/config \
--v=2 \
--testconfig=testing/density/config.yaml \
--report-dir=./reports \
--alsologtostderr \
--enable-prometheus-server=true \
--tear-down-prometheus-server=false \
--prometheus-manifest-path `pwd`/pkg/prometheus/manifests \
--prometheus-pvc-storage-class managed-nfs-storage \
--prometheus-apiserver-scrape-port 6443 \
--experimental-prometheus-snapshot-to-report-dir \
2>&1 \
| tee ./reports/clusterload.log
```

| 参数说明                                                  |                                                                                          |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `CL2_PROMETHEUS_NODE_SELECTOR='kubernetes.io/role: node'` | 避免 Prometheus 调度到虚拟节点                                                           |
| `--tear-down-prometheus-server=false`                     | 压测完不删除 Prometheus，用于查看测试数据<br>无法访问前端时可以去除这个选项              |
| `--prometheus-pvc-storage-class managed-nfs-storage`      | 这里使用 kubeasz 部署的 nfs provisioner，按实际情况填写                                  |
| `--experimental-prometheus-snapshot-to-report-dir`        | 保存压测时的 Prometheus 快照到 report 目录下<br>默认文件名为`prometheus_snapshot.tar.gz` |

### Grafana 浏览压测数据

如果在测试环境无法访问 Grafana 前端，可以在服务器上测试并拿到 `prometheus_snapshot.tar.gz`，然后在本地搭一个新的测试环境用于查看测试数据

`prometheus_snapshot.tar.gz` 解压后将 `snapshots/<date>` 下的文件夹复制到 `<pv path>/prometheus-db/` 下，一段时间后就可以在 Grafana 浏览测试数据

![](pics/Snipaste_2023-01-31_10-34-49.png)

![](pics/Snipaste_2023-01-31_10-49-15.png)

![](pics/Snipaste_2023-01-30_15-11-09.png)

![](pics/Snipaste_2023-01-30_15-14-19.png)

![](pics/Snipaste_2023-01-30_15-15-31.png)

## 附录

### kubemark 镜像列表

- wrype/kubemark:v1.24.9
- wrype/node-problem-detector:v0.8.9
- busybox:1.32

### clusterloader 镜像列表

- quay.io/prometheus-operator/prometheus-config-reloader:v0.46.0
- quay.io/prometheus-operator/prometheus-operator:v0.46.0
- grafana/grafana:6.2.0
- quay.io/prometheus/prometheus:v2.25.0
- k8simage/kube-state-metrics:v2.0.0-rc.0
- opsdockerimage/e2e-test-images-resource-consumer:1.9
- quay.io/prometheus/node-exporter:v1.0.1
- prom/pushgateway:v1.4.2
- opsdockerimage/e2e-test-images-agnhost:2.32
  > tag to k8s.gcr.io/e2e-test-images/agnhost:2.32，无法修改为其他镜像

### 参考文档

http://bingerambo.com/posts/2020/12/k8s%E9%9B%86%E7%BE%A4%E6%80%A7%E8%83%BD%E6%B5%8B%E8%AF%95-kubemark/

http://bingerambo.com/posts/2020/12/k8s%E9%9B%86%E7%BE%A4%E6%80%A7%E8%83%BD%E6%B5%8B%E8%AF%95-clusterloader/