locals {
  iptables_allow_all = <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
# Allow all incoming packets.
-A INPUT -j ACCEPT
# Enable the rules.
COMMIT
EOF

  ctl_iptables = "${var.iptables_allow_all ? local.iptables_allow_all : local.ctl_iptables_enabled}"

  ctl_iptables_enabled = <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Block all null packets.
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Reject a syn-flood attack.
-A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Block XMAS/recon packets.
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Allow all incoming packets on the loopback interface.
-A INPUT -i lo -j ACCEPT

# Allow incoming packets for SSH.
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# Allow incoming packets for the etcd client and peer endpoints.
-A INPUT -p tcp -m tcp --dport 2379 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2380 -j ACCEPT

# Allow incoming packets for DNS.
-A INPUT -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -p udp -m udp --dport 53 -j ACCEPT

# Allow incoming packets for HTTP/HTTPS.
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT

# Allow incoming packets for the K8s secure port.
-A INPUT -p tcp -m tcp --dport 6443 -j ACCEPT

# Allow incoming packets for handling unauthenticated signals
# from worker nodes.
-A INPUT -p tcp -m tcp --dport 3080 -j ACCEPT

# Allow incoming packets for established connections.
-I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow all outgoing packets.
-P OUTPUT ACCEPT

# Drop everything else.
-P INPUT DROP

# Enable the rules.
COMMIT
EOF

  wrk_iptables = "${var.iptables_allow_all ? local.iptables_allow_all : local.wrk_iptables_enabled}"

  wrk_iptables_enabled = <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Block all null packets.
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Reject a syn-flood attack.
-A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Block XMAS/recon packets.
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Allow all incoming packets on the loopback interface.
-A INPUT -i lo -j ACCEPT

# Allow incoming packets for SSH.
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# Allow incoming packets for cAdvisor, used to query container metrics.
-A INPUT -p tcp -m tcp --dport 4149 -j ACCEPT

# Allow incoming packets for the unrestricted kubelet API.
-A INPUT -p tcp -m tcp --dport 10250 -j ACCEPT

# Allow incoming packets for the unauthenticated, read-only port used
# to query the node state.
-A INPUT -p tcp -m tcp --dport 10255 -j ACCEPT

# Allow incoming packets for kube-proxy's health check server.
-A INPUT -p tcp -m tcp --dport 10256 -j ACCEPT

# Allow incoming packets for Calico's health check server.
-A INPUT -p tcp -m tcp --dport 9099 -j ACCEPT

# Allow incoming packets for NodePort services.
# https://kubernetes.io/docs/setup/independent/install-kubeadm/
-A INPUT -p tcp -m multiport --dports 30000:32767 -j ACCEPT

# Allow incoming packets for established connections.
-I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow all outgoing packets.
-P OUTPUT ACCEPT

# Drop everything else.
-P INPUT DROP

# Enable the rules.
COMMIT
EOF
}
