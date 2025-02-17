MANIFESTS_DIR ?= ./kubernetes

build:
	docker-compose build

run:
	docker-compose up

helm-dependencies:
	helm dependency build $(MANIFESTS_DIR)

lint:
	helm lint $(MANIFESTS_DIR) -f $(MANIFESTS_DIR)/values.yaml

template:
	helm template $(MANIFESTS_DIR) -f $(MANIFESTS_DIR)/values.yaml
