////////////////////////////////////////////////////////////////////////////////
//                               ContainerD                                   //
////////////////////////////////////////////////////////////////////////////////

data "template_file" "wrk_cni_bridge_config" {
  count = "${var.wrk_count}"

  template = <<EOF
{
  "cniVersion": "0.3.1",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cnio0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [
        {
          "subnet": "$${pod_cidr}"
        }
      ]
    ],
    "routes": [
      {
        "dst": "0.0.0.0/0"
      }
    ]
  }
}
EOF

  vars {
    pod_cidr = "${data.template_file.wrk_pod_cidr.*.rendered[count.index]}"
  }
}

locals {
  wrk_cni_loopback_config = <<EOF
{
  "cniVersion": "0.3.1",
  "type": "loopback"
}
EOF

  wrk_containerd_config = <<EOF
root = "/var/lib/containerd"
state = "/var/run/containerd"
subreaper = true

[grpc]
  address = "/var/run/containerd/containerd.sock"
  uid = 0
  gid = 0

[plugins]
  [plugins.opt]
    path = "/opt/containerd"
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/opt/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/opt/bin/runsc"
      runtime_root = "/var/run/containerd/runsc"
EOF

  wrk_containerd_service = <<EOF
[Unit]
Description=containerd.service
Documentation=https://containerd.io
After=bins.service
Requires=bins.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
WorkingDirectory=/var/lib/containerd
EnvironmentFile=/etc/default/path
ExecStartPre=/usr/sbin/modprobe overlay
ExecStart=/opt/bin/containerd
EOF
}
