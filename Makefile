SHELL := bash

VERSION_VALUE ?= $(shell git rev-parse --short HEAD 2>/dev/null)
DOCKER_IMAGE_REPO ?= sbom
DOCKER_DEST ?= $(DOCKER_IMAGE_REPO):$(VERSION_VALUE)
GCR ?= us-east4-docker.pkg.dev/travis-ci-prod-services-1/travis
GCR_IMAGE ?= $(GCR)/$(DOCKER_IMAGE_REPO)

ifdef $$GCR_ACCOUNT_JSON_ENC
	GCR_ACCOUNT_JSON_ENC := $$GCR_ACCOUNT_JSON_ENC
endif
ifndef $$TRAVIS_BRANCH
	TRAVIS_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
endif
ifneq ($(TRAVIS_BRANCH),master)
	BRANCH := $(shell echo "$(TRAVIS_BRANCH)" | sed 's/\//_/')
	VERSION_VALUE := $(VERSION_VALUE)-$(BRANCH)
endif
ifdef $$TRAVIS_PULL_REQUEST
	TRAVIS_PULL_REQUEST := $$TRAVIS_PULL_REQUEST
endif

DOCKER ?= docker

.PHONY: docker-build
docker-build:
	$(DOCKER) build -t $(DOCKER_DEST) .

.PHONY: docker-push
docker-push:
	$(shell echo ${GCR_ACCOUNT_JSON_ENC} | openssl enc -d -base64 -A > ./gce-account.json)
	cat ./gce-account.json | $(DOCKER) login -u _json_key --password-stdin https://us-east4-docker.pkg.dev
	#rm -f ./gce-account.json
	$(DOCKER) tag $(DOCKER_DEST) $(GCR_IMAGE):$(VERSION_VALUE)
	$(DOCKER) push $(GCR_IMAGE):$(VERSION_VALUE)

.PHONY: docker-latest
docker-latest:
	$(DOCKER) tag $(DOCKER_DEST) $(QUAY_IMAGE):latest
	$(DOCKER) push $(QUAY_IMAGE):latest

.PHONY: ship
ship: docker-build docker-push

ifeq ($(TRAVIS_BRANCH),master)
ifeq ($(TRAVIS_PULL_REQUEST),false)
ship: docker-latest
endif
endif
