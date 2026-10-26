# Course command reference

This guide groups LedgerFlow commands by operational workflow.

Use it alongside the course lessons. It is not an instruction to execute every exercise consecutively: security configurations, integration overlays, and Kubernetes environments have different prerequisites.

## Conventions

- Run commands from the repository root.
- Examples use Bash unless explicitly labelled otherwise.
- Run one failure exercise at a time.
- Verify recovery before moving to another exercise.
- Commands using `broker-1:19092` below run inside a container on the Docker network.
- The Kafka CLI examples in the base-environment sections assume the plaintext configuration.

On Windows Git Bash:

```bash
export MSYS_NO_PATHCONV=1
```

This setting prevents Git Bash from rewriting container paths such as `/opt/kafka/bin/kafka-topics.sh`.

## 1. Check prerequisites

```bash
git --version
docker version
docker compose version
bash --version
```

If using Make:

```bash
make --version
```

For local Go development:

```bash
go version
```

Use the Go toolchain version required by `go.mod`.

For Kubernetes exercises:

```bash
kind version
kubectl version --client
helm version
```

Docker commands require a running Docker engine.

## 2. Start the Docker Compose environment

```bash
make up
```

Equivalent:

```bash
docker compose -f deployments/docker/compose.kafka.yaml up -d --build
```

Inspect all services, including stopped and completed containers:

```bash
docker compose -f deployments/docker/compose.kafka.yaml ps -a
```

A one-time initialisation container may complete successfully and exit. Long-running services should remain running; services with health checks should become healthy.

Initial image pulls and builds can take time.

## 3. Initialise topics

After Kafka is ready:

```bash
make topics
```

Equivalent:

```bash
bash scripts/init-topics.sh
```

List topics:

```bash
docker exec ledgerflow-broker-1 \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server broker-1:19092 \
  --list
```

Describe the transaction topic:

```bash
docker exec ledgerflow-broker-1 \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server broker-1:19092 \
  --describe \
  --topic ledgerflow.transactions
```

Inspect partition leaders, replica assignments, and ISR membership.

A replica assignment lists intended replicas. ISR membership identifies replicas currently considered in sync.

## 4. Verify the application

Check API endpoints:

```bash
curl --fail http://localhost:8080/health/live
curl --fail http://localhost:8080/health/ready
```

Run the smoke test:

```bash
make smoke
```

Equivalent:

```bash
bash scripts/smoke-test.sh
```

Expected evidence includes:

- The API accepts a transaction.
- The transaction is persisted.
- Debit and credit ledger entries are present.
- The event has a processed-event marker.
- Fraud and notification output events are found.

A successful liveness request alone does not verify this complete path.

## 5. Submit a fixture manually

```bash
curl -i \
  -H 'Content-Type: application/json' \
  --data-binary @fixtures/transaction-approved.json \
  http://localhost:8080/api/v1/transactions
```

The fixture contains fixed identifiers. Repeating it may exercise duplicate-event protection.

Use a fresh identifier when you want a new independent transaction.

## 6. Inspect application logs

```bash
docker compose -f deployments/docker/compose.kafka.yaml \
  logs --tail=100 transaction-api ledger-service fraud-service notification-service
```

Follow one service:

```bash
docker compose -f deployments/docker/compose.kafka.yaml \
  logs -f ledger-service
```

Check the earliest relevant failure rather than only the final retry message.

## 7. Inspect consumer groups

```bash
make inspect-groups
```

Equivalent:

```bash
bash scripts/labs/inspect-consumer-groups.sh
```

Describe the ledger consumer group directly:

```bash
docker exec ledgerflow-broker-1 \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server broker-1:19092 \
  --group ledger-service \
  --describe
```

Compare committed offsets, log-end offsets, lag, and active members.

An empty or missing group requires context: the consumer may not have started, joined, or committed an offset yet.

## 8. Demonstrate consumer lag

Prerequisite: healthy base environment.

```bash
make lab-lag
```

Equivalent:

```bash
bash scripts/labs/consumer-lag.sh
```

The exercise stops the ledger consumer, submits transactions, inspects lag, restarts the consumer, and observes recovery.

Afterward:

```bash
make inspect-groups
make smoke
```

If the exercise is interrupted, restore the consumer:

```bash
docker compose -f deployments/docker/compose.kafka.yaml start ledger-service
```

Confirm that the consumer is running and processing before interpreting a zero-lag result.

## 9. Demonstrate broker failure

This exercise intentionally stops a broker.

```bash
make lab-broker-failure
```

Equivalent:

```bash
bash scripts/labs/broker-failure.sh
```

Compare topic state before, during, and after the failure.

Look for:

- Leader changes where the failed broker was leader.
- Reduced ISR membership.
- Replica recovery after the broker returns.

If interrupted, restore the default failed broker:

```bash
docker compose -f deployments/docker/compose.kafka.yaml start broker-3
```

Verify:

```bash
make inspect-groups
make smoke
```

## 10. Demonstrate producer durability

This exercise intentionally stops two brokers.

```bash
make lab-producer-reliability
```

Equivalent:

```bash
bash scripts/labs/producer-reliability.sh
```

The exercise compares write behaviour while replica availability is reduced and after recovery.

A rejected HTTP request alone does not establish the Kafka failure cause. Correlate:

- Topic durability settings.
- ISR membership.
- Producer configuration.
- API and broker logs.

If interrupted:

```bash
docker compose -f deployments/docker/compose.kafka.yaml start broker-2 broker-3
```

Wait for recovery, inspect the topic, and run:

```bash
make smoke
```

## 11. Demonstrate retention and compaction

```bash
make lab-cleanup
```

Equivalent:

```bash
bash scripts/labs/topic-cleanup.sh
```

Despite its name, this command creates and populates retention and compaction demonstration topics. It is not general Docker cleanup.

Inspect the script for the configured topic names and settings.

Retention deletion and compaction run asynchronously. A configured interval does not guarantee visible cleanup at an exact moment.

Compaction retains the latest value for a key as eligible segments are cleaned; it does not immediately rewrite every record.

## 12. Inspect monitoring

Base-environment endpoints:

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000
- Alertmanager: http://localhost:9093

Inspect exporter responses:

```bash
curl --fail http://localhost:9308/metrics
curl --fail http://localhost:9404/metrics
```

Check Prometheus target health before investigating an empty dashboard.

Distinguish:

- Broker/JVM metrics.
- Topic and consumer-group metrics.
- Application metrics.
- Recording-rule results used by dashboards.

A running exporter does not prove that Prometheus is successfully scraping it.

## 13. Start integration services

Prerequisite: healthy base environment.

```bash
make integration-up
```

Equivalent:

```bash
bash scripts/labs/integration-up.sh
```

Inspect the merged environment:

```bash
docker compose \
  -f deployments/docker/compose.kafka.yaml \
  -f deployments/docker/compose.integration.yaml \
  ps -a
```

Check Kafka Connect:

```bash
curl --fail http://localhost:8083/connectors
```

Check Schema Registry:

```bash
curl --fail http://localhost:8085/subjects
```

An empty JSON array can be a valid response when nothing has been registered.

## 14. Configure PostgreSQL CDC

Prerequisites:

- Integration services are running.
- PostgreSQL has the CDC settings required by the connector.
- Connector configuration matches the running environment.
- Python 3 is available if required by the helper.

```bash
make connect-debezium
```

Equivalent:

```bash
bash scripts/labs/connect-debezium.sh
```

Check connector and task status:

```bash
curl --fail \
  http://localhost:8083/connectors/ledgerflow-postgres-cdc/status
```

Inspect task status as well as connector status. A running connector with a failed task is not a healthy CDC pipeline.

## 15. Start the MirrorMaker exercise

```bash
make mirrormaker-up
```

Equivalent:

```bash
bash scripts/labs/mirrormaker.sh
```

Inspect the merged environment:

```bash
docker compose \
  -f deployments/docker/compose.kafka.yaml \
  -f deployments/docker/compose.mirrormaker.yaml \
  ps -a
```

Topic existence on the destination cluster is preliminary evidence. Verify record replication with a newly submitted transaction and its identifier.

Replication between clusters does not itself implement application failover or prove that recovery objectives are met.

## 16. Verify duplicate-event handling

Prerequisite: healthy base environment and ledger consumer.

```bash
make lab-idempotency
```

Equivalent:

```bash
bash scripts/labs/idempotency.sh
```

For the event generated by the exercise, the expected durable counts are:

```text
transactions=1
ledger_entries=2
processed_events=1
```

The two ledger entries represent the debit and credit entries for one transaction.

Application-level duplicate protection and Kafka producer idempotence address different failure boundaries. Verify the database result rather than inferring it from producer settings.

## 17. Demonstrate dead-letter handling

```bash
make lab-dlt
```

Equivalent:

```bash
bash scripts/labs/dlt.sh
```

This exercise deliberately publishes malformed input and checks for its dead-letter representation.

A dead-letter topic is an operational holding area. Investigating, correcting, and replaying records require a separate controlled process.

Verify that valid transactions still process:

```bash
make smoke
```

## 18. Security workflow boundaries

Certificate-generation helper:

```bash
make tls-generate
```

ACL helper:

```bash
make acl-apply
```

These commands are not a complete security startup sequence.

Before running a security exercise, use the matching course configuration for:

- Broker listeners and advertised listeners.
- Certificate mounts and trust.
- Client security properties.
- SASL mechanism and credentials, where applicable.
- Authorizer and administrative principals.
- Health checks using the matching client configuration.

Do not reuse plaintext CLI examples unchanged against a secured listener.

Certificate generation may replace existing generated certificate files. Read the helper before rerunning it.

ACL application requires an enabled authorizer and an authorised administrator.

## 19. Create the Kubernetes environment

Check tools and Docker availability first.

```bash
make kind-create
```

Equivalent:

```bash
bash scripts/kubernetes/create-kind.sh
```

Verify the selected context:

```bash
kubectl config current-context
kubectl config use-context kind-ledgerflow
kubectl get nodes
```

Confirm that the context is the intended disposable course cluster before applying or deleting resources.

## 20. Install Strimzi and Kafka

```bash
make k8s-strimzi
```

Equivalent:

```bash
bash scripts/kubernetes/install-strimzi.sh
```

Inspect resources:

```bash
kubectl get pods -n strimzi-system
kubectl get pods -n ledgerflow
kubectl get kafka,kafkanodepool,kafkatopic -n ledgerflow
```

Wait for the operator and Kafka resources to become ready before deploying dependent applications.

If the helper downloads an operator manifest using `latest`, the retrieved version can change. Use the operator version compatible with the checked-in Kafka manifests and the course instructions.

## 21. Build and load application images

```bash
make k8s-load-apps
```

Equivalent:

```bash
bash scripts/kubernetes/build-load-apps.sh
```

The helper builds local application images and loads them into the kind cluster.

Rebuild and reload after changing application code. An existing image tag does not prove that cluster nodes have the updated image.

## 22. Deploy the applications

```bash
make k8s-deploy-apps
```

Equivalent:

```bash
bash scripts/kubernetes/deploy-apps.sh
```

Inspect:

```bash
kubectl get pods -n ledgerflow -o wide
kubectl get deployments,services,pvc -n ledgerflow
```

Check rollouts:

```bash
kubectl rollout status deployment/transaction-api -n ledgerflow
kubectl rollout status deployment/ledger-service -n ledgerflow
kubectl rollout status deployment/fraud-service -n ledgerflow
kubectl rollout status deployment/notification-service -n ledgerflow
```

## 23. Collect Kubernetes troubleshooting evidence

```bash
make k8s-troubleshoot
```

Equivalent:

```bash
bash scripts/kubernetes/troubleshoot.sh
```

Additional evidence:

```bash
kubectl get events -n ledgerflow --sort-by=.lastTimestamp
kubectl logs deployment/transaction-api -n ledgerflow --tail=100
kubectl logs deployment/ledger-service -n ledgerflow --tail=100
```

For a specific failing pod:

```bash
kubectl describe pod POD_NAME -n ledgerflow
kubectl logs POD_NAME -n ledgerflow --previous
```

Replace `POD_NAME` with an actual pod name. Previous-container logs are available only when a previous container instance exists.

## 24. Stop the Docker environment

Base environment:

```bash
make down
```

Equivalent:

```bash
docker compose -f deployments/docker/compose.kafka.yaml down
```

Named volumes are retained.

If both integration and MirrorMaker overlays were used, include them when stopping the combined environment:

```bash
docker compose \
  -f deployments/docker/compose.kafka.yaml \
  -f deployments/docker/compose.integration.yaml \
  -f deployments/docker/compose.mirrormaker.yaml \
  down
```

Include any additional security overlays used to start your environment.

## 25. Reset persistent base data

**Destructive: deletes persistent data belonging to the base Compose environment.**

```bash
make reset
```

Equivalent helper:

```bash
bash scripts/reset.sh
```

The helper removes base volumes, starts the base environment, waits for Kafka, and initialises topics.

After readiness is established:

```bash
make smoke
```

Do not use reset to recover data you need to preserve.

## 26. Delete the kind cluster

**Destructive: removes the local Kubernetes cluster and its cluster-local data.**

```bash
kind delete cluster --name ledgerflow
```

Deleting the cluster does not remove every Docker image from the host.

## 27. Local development verification

```bash
go test ./...
go vet ./...
go build ./...
```

Format source files:

```bash
make fmt
```

Formatting edits the working tree. Review changes before committing.