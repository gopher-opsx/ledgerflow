.PHONY: fmt test vet build run-api

fmt:
	gofmt -w ./cmd ./internal

test:
	go test ./...

vet:
	go vet ./...

build:
	go build ./...

run-api:
	go run ./cmd/transaction-api
