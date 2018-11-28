all: build

build: certs images

TLS_CA_CRT ?= ca.crt
TLS_CA_KEY ?= ca.key
TLS_CA_CRT := $(abspath $(TLS_CA_CRT))
TLS_CA_KEY := $(abspath $(TLS_CA_KEY))
export TLS_CA_CRT TLS_CA_KEY

certs: $(TLS_CA_CRT) $(TLS_CA_KEY)
$(TLS_CA_CRT) $(TLS_CA_KEY):
	hack/new-ca.sh

.vmctf.built:	Dockerfile entrypoint.sh \
				ldap/Dockerfile ldap/slapd.sh $(wildcard ldap/*.tf)
	docker build -t vmctf .
	@touch $@

images: .vmctf.built

.PHONY: build certs images
