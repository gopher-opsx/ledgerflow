.PHONY: fmt test vet build up down topics smoke reset logs

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
