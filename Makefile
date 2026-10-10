# Student lab shortcuts; run from the repository root with Make and Bash available.
# Start the base lab, create topics, then use smoke to verify the transaction path.
# reset removes persistent data; down retains it.

.PHONY: fmt test vet build up down topics smoke reset logs inspect-groups lab-lag lab-cleanup lab-broker-failure lab-producer-reliability integration-up connect-debezium mirrormaker-up lab-idempotency lab-dlt kind-create k8s-strimzi k8s-load-apps k8s-deploy-apps k8s-troubleshoot tls-generate acl-apply

# Format Go source in place.
fmt:
	gofmt -w ./cmd ./internal

# Run the existing Go test suite.
test:
	go test ./...

# Check Go code for likely mistakes.
vet:
	go vet ./...

# Compile all Go packages.
build:
	go build ./...

# Build and start the complete base Compose lab.
up:
	docker compose -f deployments/docker/compose.kafka.yaml up -d --build

# Stop the base lab while retaining named volumes.
down:
	docker compose -f deployments/docker/compose.kafka.yaml down

# Create the banking topics.
topics:
	./scripts/init-topics.sh

# Verify the end-to-end synthetic transaction path.
smoke:
	./scripts/smoke-test.sh

# Delete persistent lab data and recreate the base environment.
reset:
	./scripts/reset.sh

# Lists groups and describes offsets, lag, and the selected topic using standard Kafka tools.
inspect-groups:
	./scripts/labs/inspect-consumer-groups.sh

# Pauses the ledger consumer, creates a backlog, and observes recovery after restarting it.
lab-lag:
	./scripts/labs/consumer-lag.sh

# Creates and populates separate retention and compaction demonstration topics. Cleanup happens asynchronously.
lab-cleanup:
	./scripts/labs/topic-cleanup.sh

# Stops a broker to demonstrate replication recovery. Run only in the isolated course lab.
lab-broker-failure:
	./scripts/labs/broker-failure.sh

# Removes two brokers and compares write behavior before and after recovery. A non-202 response alone does not establish the Kafka failure cause.
lab-producer-reliability:
	./scripts/labs/producer-reliability.sh

# Starts Connect, registry, and Streams by merging the integration overlay with the base Compose file.
integration-up:
	./scripts/labs/integration-up.sh

# Registers the PostgreSQL CDC connector with Kafka Connect. Requires the integration services to be running.
connect-debezium:
	./scripts/labs/connect-debezium.sh

# Starts the secondary cluster and checks that the mirrored transaction topic appears. Topic existence alone does not prove record replication.
mirrormaker-up:
	./scripts/labs/mirrormaker.sh

# Submits the same event twice and checks that only one transaction and two ledger entries persist.
lab-idempotency:
	./scripts/labs/idempotency.sh

# Publishes malformed JSON and looks for the same payload on the ledger dead-letter topic.
lab-dlt:
	./scripts/labs/dlt.sh

# Creates the multi-node kind lab from the checked-in cluster configuration.
kind-create:
	./scripts/kubernetes/create-kind.sh

# Installs the Strimzi operator and Kafka resources for the Kubernetes lab.
k8s-strimzi:
	./scripts/kubernetes/install-strimzi.sh

# Builds local application images and loads them into the kind cluster; no remote registry is required.
k8s-load-apps:
	./scripts/kubernetes/build-load-apps.sh

# Applies the namespace, PostgreSQL, and application manifests to the current Kubernetes context.
k8s-deploy-apps:
	./scripts/kubernetes/deploy-apps.sh

# Collects Kubernetes workload evidence for the lab. Review the selected context before running.
k8s-troubleshoot:
	./scripts/kubernetes/troubleshoot.sh

# Replaces generated lab certificate files and builds broker keystores and a shared truststore. Requires OpenSSL and keytool.
tls-generate:
	./scripts/security/generate-tls.sh

# Adds topic and consumer-group permissions for the lab principal using the mounted admin credentials.
acl-apply:
	./scripts/security/apply-acls.sh
