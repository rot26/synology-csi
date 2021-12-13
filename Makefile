#  Copyright 2021 Synology Inc.

REGISTRY_NAME=rot26
IMAGE_NAME=synology-csi
IMAGE_VERSION=v1.0.0
IMAGE_TAG=$(REGISTRY_NAME)/$(IMAGE_NAME):$(IMAGE_VERSION)

BUILD_ENV=CGO_ENABLED=0
BUILD_FLAGS="-extldflags \"-static\""

.PHONY: all clean synology-csi-driver synocli test docker-build release

all: synology-csi-driver

release:
	goreleaser \
		release \
			--auto-snapshot \
			--config .goreleaser.local.yml \
			--parallelism 8 \
			--rm-dist \
			--skip-announce \
			--skip-publish \
			--skip-sign \
			--skip-validate \
			--debug \
	;

synology-csi-driver:
	@mkdir -p bin
	$(BUILD_ENV) go build -v -ldflags $(BUILD_FLAGS) -o ./bin/synology-csi-driver ./

docker-build:
	docker build -f Dockerfile -t $(IMAGE_TAG) .

synocli:
	@mkdir -p bin
	$(BUILD_ENV) go build -v -ldflags $(BUILD_FLAGS) -o ./bin/synocli ./synocli

test:
	go test -v ./test/...
clean:
	-rm -rf ./bin
