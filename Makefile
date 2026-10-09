.PHONY: fmt test vet build up down topics smoke reset logs inspect-groups lab-lag lab-cleanup lab-broker-failure lab-producer-reliability integration-up connect-debezium mirrormaker-up lab-idempotency lab-dlt kind-create k8s-strimzi k8s-load-apps k8s-deploy-apps k8s-troubleshoot tls-generate acl-apply

fmt:
	gofmt -w ./cmd ./internal

test:
	go test ./...

vet:
	go vet ./...

build:
	go build ./...

up:
	docker compose -f deployments/docker/compose.kafka.yaml up -d --build

down:
	docker compose -f deployments/docker/compose.kafka.yaml down

topics:
	./scripts/init-topics.sh

smoke:
	./scripts/smoke-test.sh

reset:
	./scripts/reset.sh

inspect-groups:
	./scripts/labs/inspect-consumer-groups.sh

lab-lag:
	./scripts/labs/consumer-lag.sh

lab-cleanup:
	./scripts/labs/topic-cleanup.sh

lab-broker-failure:
	./scripts/labs/broker-failure.sh

lab-producer-reliability:
	./scripts/labs/producer-reliability.sh

integration-up:
	./scripts/labs/integration-up.sh

connect-debezium:
	./scripts/labs/connect-debezium.sh

mirrormaker-up:
	./scripts/labs/mirrormaker.sh

lab-idempotency:
	./scripts/labs/idempotency.sh

lab-dlt:
	./scripts/labs/dlt.sh

kind-create:
	./scripts/kubernetes/create-kind.sh

k8s-strimzi:
	./scripts/kubernetes/install-strimzi.sh

k8s-load-apps:
	./scripts/kubernetes/build-load-apps.sh

k8s-deploy-apps:
	./scripts/kubernetes/deploy-apps.sh

k8s-troubleshoot:
	./scripts/kubernetes/troubleshoot.sh

tls-generate:
	./scripts/security/generate-tls.sh

acl-apply:
	./scripts/security/apply-acls.sh
