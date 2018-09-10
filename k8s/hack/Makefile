all: build

docker-build-golang-centos: Dockerfile.golang-centos7.5.1804
	docker build -t akutz/golang:centos -f "$<" .
	docker build -t akutz/golang:centos7 -f "$<" .
	docker build -t akutz/golang:centos7.5 -f "$<" .
	docker build -t akutz/golang:centos7.5.1804 -f "$<" .

docker-push-golang-centos: | docker-build-golang-centos
	docker push akutz/golang:centos
	docker push akutz/golang:centos7
	docker push akutz/golang:centos7.5
	docker push akutz/golang:centos7.5.1804

docker-build-crio: Dockerfile.crio-1.11.2.build
	docker build -t akutz/crio:latest.build -f "$<" .
	docker build -t akutz/crio:1.11.2.build -f "$<" .

docker-push-crio: docker-build-crio
	docker push akutz/crio:latest.build
	docker push akutz/crio:1.11.2.build

docker-build-skopeo: Dockerfile.skopeo-0.1.31.build
	docker build -t akutz/skopeo:latest.build -f "$<" .
	docker build -t akutz/skopeo:0.1.31.build -f "$<" .

docker-push-skopeo: docker-build-skopeo
	docker push akutz/skopeo:latest.build
	docker push akutz/skopeo:0.1.31.build

docker-build:	docker-build-golang-centos \
				docker-build-cri-o \
				docker-build-skopeo

build: docker-build

push: 	docker-push-golang-centos \
		docker-push-crio \
		docker-push-skopeo
