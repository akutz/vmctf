#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

export ETCDCTL_API=3
export ETCDCTL_CERT=${tls_crt}
export ETCDCTL_KEY=${tls_key}
export ETCDCTL_CACERT=${tls_ca}
export ETCDCTL_ENDPOINTS=${etcd_endpoints}
