# Dockerfile for building images to run kubeasz in a container
#
# @author:  gjmzj
# @repo:     https://github.com/easzlab/kubeasz

FROM easzlab/ansible:2.10.6-lite

COPY . /etc/kubeasz/
RUN set -x \
    && chmod +x /etc/kubeasz/ezctl /etc/kubeasz/ezdown \
    && ln -s -f /etc/kubeasz/ezctl /usr/bin/ezctl \
    && ln -s -f /etc/kubeasz/ezdown /usr/bin/ezdown