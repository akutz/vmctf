all: build

build: certs images

HOST_FQDN := ldap.vmware.ci
HOST_IPV4_PUBLIC := 54.245.51.200
HOST_IPV4_PRIVATE := 192.168.2.3
IMAGE_NAME := vmctf-ldap
IMAGE_SRCS := Dockerfile slapd.sh $(wildcard *.tf)

TLS_CA_CRT ?= ../ca.crt
TLS_CA_KEY ?= ../ca.key
TLS_CA_CRT := $(abspath $(TLS_CA_CRT))
TLS_CA_KEY := $(abspath $(TLS_CA_KEY))
export TLS_CA_CRT TLS_CA_KEY

TLS_CRT_OUT ?= $(HOST_FQDN).crt
TLS_KEY_OUT ?= $(HOST_FQDN).key
TLS_CRT_OUT := $(abspath $(TLS_CRT_OUT))
TLS_KEY_OUT := $(abspath $(TLS_KEY_OUT))
export TLS_CRT_OUT TLS_KEY_OUT

TLS_SAN ?= true
TLS_SAN_IP ?= 127.0.0.1 $(HOST_IPV4_PRIVATE) $(HOST_IPV4_PUBLIC)
TLS_SAN_DNS ?= localhost $(HOST_FQDN)
export TLS_SAN TLS_SAN_IP TLS_SAN_DNS

certs: $(TLS_CRT_OUT) $(TLS_KEY_OUT)
$(TLS_CRT_OUT) $(TLS_KEY_OUT):
	../hack/new-cert.sh $(HOST_FQDN)

images: .$(IMAGE_NAME).built
.$(IMAGE_NAME).built: $(IMAGE_SRCS)
	docker build -t $(IMAGE_NAME) .
	@touch $@

.PHONY: build certs images
