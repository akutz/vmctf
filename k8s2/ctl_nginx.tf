data "template_file" "ctl_nginx_conf" {
  template = <<EOF
user                   nginx nobody;
pid                    /var/run/nginx.pid;
error_log              syslog:server=unix:/dev/log;
worker_processes       1;

events {
  worker_connections   1024;
}

http {
  default_type         application/octet-stream;
  log_format           main  '$$remote_addr - $$remote_user [$$time_local] "$$request" '
                             '$$status $$body_bytes_sent "$$http_referer" '
                             '"$$http_user_agent" "$$http_x_forwarded_for"';
  access_log           syslog:server=unix:/dev/log main;
  sendfile             on;
  keepalive_timeout    65;
  gzip                 on;

    server {
      listen      80;
      server_name $${server_name};

      location = /healthz {
        proxy_pass                    https://127.0.0.1:443/healthz;
        proxy_ssl_trusted_certificate /etc/ssl/ca.crt;
        proxy_set_header Host         $$host;
        proxy_set_header X-Real-IP    $$remote_addr;
      }

      location / {
        return 301 http://bit.ly/cnx-cicd-notes;
      }
    }

    server {
      listen      3080;
      server_name $${server_name};
      access_log  /var/log/nginx/k8s-worker-signal.log main;
      return      200;
    }
}
EOF

  vars {
    server_name = "${local.cluster_fqdn}"
  }
}

locals {
  ctl_nginx_service = <<EOF
[Unit]
Description=nginx.service
Documentation=http://bit.ly/howto-build-nginx-for-container-linux
After=bins.service syslog.target nss-lookup.target
Requires=bins.service

[Install]
WantedBy=multi-user.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid

# Truncate the K8s worker signal log when nginx is started via SystemD.
ExecStartPre=/bin/rm -f /var/log/nginx/k8s-worker-signal.log

ExecStartPre=/opt/bin/nginx -t
ExecStart=/opt/bin/nginx
ExecReload=/opt/bin/nginx -s reload
ExecStop=/bin/kill -s QUIT $$MAINPID
PrivateTmp=true
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                            Handle Worker Signals                           //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "ctl_handle_worker_signals_env" {
  template = <<EOF
ETCD_DISCOVERY=$${etcd_discovery}
WORKER_COUNT=$${wrk_count}
EOF

  vars {
    wrk_count      = "${var.wrk_count}"
    etcd_discovery = "${data.http.etcd_discovery.body}"
  }
}

locals {
  ctl_handle_worker_signals_service = <<EOF
[Unit]
Description=handle-worker-signals.service
After=nginx.service etcd.service
Requires=nginx.service etcd.service

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/var/lib/kubernetes
EnvironmentFile=/etc/default/etcdctl
EnvironmentFile=/etc/default/handle-worker-signals
ExecStart=/opt/bin/handle-worker-signals.sh
EOF
}
