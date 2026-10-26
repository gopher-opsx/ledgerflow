# LedgerFlow

LedgerFlow is an event-driven transaction application used in **Apache Kafka and Kubernetes: Production Operations**.

It provides a practical environment for learning Kafka operations through application traffic, monitoring, controlled failures, security exercises, integrations, and Kubernetes deployment.

Repository: https://github.com/gopher-opsx/ledgerflow

## Start here

- [Course command reference](docs/course-commands.md)
- [Troubleshooting and shell guide](docs/troubleshooting.md)

Run commands from the repository root unless a guide states otherwise.

## Application architecture

| Component | Responsibility |
|---|---|
| Transaction API | Accepts transaction requests and publishes transaction events |
| Ledger Service | Consumes transactions and persists transaction and ledger records in PostgreSQL |
| Fraud Service | Consumes transactions and publishes fraud results |
| Notification Service | Consumes transactions and publishes notification events |
| PostgreSQL | Stores durable application data |

The main Kafka topics include:

- `ledgerflow.transactions`
- `ledgerflow.fraud-results`
- `ledgerflow.notifications`

Additional exercises introduce dead-letter handling, retention, compaction, integrations, and replication between clusters.

The application has an HTTP API. A browser-based application frontend is not required.

## What you can practise

- Kafka running in KRaft mode
- Topics, partitions, replication, leaders, and in-sync replicas
- Consumer groups, offsets, and lag
- Producer durability and broker failure recovery
- Prometheus, Grafana, JMX metrics, and alerting
- Retention and log compaction
- Kafka Connect and PostgreSQL CDC
- Schema Registry and stream processing
- MirrorMaker 2
- TLS, authentication, and ACL concepts
- Idempotent application processing and dead-letter handling
- Kubernetes deployment with kind and Strimzi

This is an educational environment for practising production operations. Its example credentials, local networking, resource allocations, and failure exercises require adaptation before use in a production environment.

## Prerequisites

For the Docker Compose exercises:

- Git
- Docker Engine with Docker Compose v2, or Docker Desktop
- Bash
- GNU Make, if using the Makefile shortcuts
- curl

For additional workflows:

| Tool | Required for |
|---|---|
| Go | Local compilation, tests, and static checks; use the version declared in `go.mod` |
| Python 3 | Scripts that process connector configuration |
| OpenSSL and Java `keytool` | Certificate-generation exercises |
| kind | Local Kubernetes cluster |
| kubectl | Kubernetes administration |
| Helm | Helm-based monitoring installation |

Some container images may require registry authentication.

On Windows, use Git Bash or a configured WSL environment for the Bash scripts. PowerShell can run Docker and kubectl commands directly, but Bash scripts and Bash syntax require Bash.

See the [shell guide](docs/troubleshooting.md#shell-differences).

## Quick start

Clone the repository:

```bash
git clone https://github.com/gopher-opsx/ledgerflow.git
cd ledgerflow
```

On Windows Git Bash, disable automatic path conversion for the current session:

```bash
export MSYS_NO_PATHCONV=1
```

Build and start the base environment:

```bash
make up
```

Inspect the services:

```bash
docker compose -f deployments/docker/compose.kafka.yaml ps -a
```

Wait for Kafka and PostgreSQL to be ready, then initialise topics:

```bash
make topics
```

Run the end-to-end smoke test:

```bash
make smoke
```

The smoke test checks the transaction API, database persistence, ledger entries, processed-event tracking, fraud results, and notification events.

### Without GNU Make

```bash
docker compose -f deployments/docker/compose.kafka.yaml up -d --build
bash scripts/init-topics.sh
bash scripts/smoke-test.sh
```

## Local endpoints

These addresses apply to the base Docker Compose environment.

| Service | Address |
|---|---|
| Transaction API | http://localhost:8080 |
| API liveness | http://localhost:8080/health/live |
| API readiness | http://localhost:8080/health/ready |
| API metrics | http://localhost:8080/metrics |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |
| Alertmanager | http://localhost:9093 |
| Kafka Exporter | http://localhost:9308/metrics |

Integration services, when started:

| Service | Address |
|---|---|
| Kafka Connect | http://localhost:8083 |
| Schema Registry | http://localhost:8085 |
| Schema Registry UI | http://localhost:8888 |

Check the relevant Compose configuration for credentials and any changed port mappings.

Docker service names such as `broker-1` resolve inside the Compose network. They are not interchangeable with host addresses.

## Submit a transaction

From Bash:

```bash
curl -i \
  -H 'Content-Type: application/json' \
  --data-binary @fixtures/transaction-approved.json \
  http://localhost:8080/api/v1/transactions
```

An accepted request does not by itself prove downstream processing completed. Use the smoke test, consumer evidence, and database verification.

For repeated exercises, use unique event and transaction identifiers unless deliberately testing duplicate processing.

## Useful commands

| Task | Command |
|---|---|
| Start base environment | `make up` |
| Initialise topics | `make topics` |
| Verify application flow | `make smoke` |
| Inspect groups and topic | `make inspect-groups` |
| Demonstrate consumer lag | `make lab-lag` |
| Demonstrate broker failure | `make lab-broker-failure` |
| Demonstrate producer durability | `make lab-producer-reliability` |
| Demonstrate retention and compaction | `make lab-cleanup` |
| Start integration services | `make integration-up` |
| Configure Debezium | `make connect-debezium` |
| Start MirrorMaker exercise | `make mirrormaker-up` |
| Verify duplicate-event handling | `make lab-idempotency` |
| Demonstrate dead-letter handling | `make lab-dlt` |
| Create kind cluster | `make kind-create` |
| Install Strimzi and Kafka resources | `make k8s-strimzi` |
| Build and load application images | `make k8s-load-apps` |
| Deploy applications | `make k8s-deploy-apps` |
| Collect Kubernetes evidence | `make k8s-troubleshoot` |
| Stop base environment | `make down` |

Failure exercises intentionally interrupt services. Run them individually and verify recovery before starting another exercise.

Security workflows require the matching broker and client configuration. Certificate generation or ACL application alone does not enable a secured environment.

## Inspect logs

```bash
docker compose -f deployments/docker/compose.kafka.yaml logs --tail=100 transaction-api ledger-service
```

Follow a service:

```bash
docker compose -f deployments/docker/compose.kafka.yaml logs -f ledger-service
```

Press Ctrl+C to stop following logs.

## Stop and reset

Stop the base environment while retaining named volumes:

```bash
make down
```

**Delete persistent base-environment data and recreate the environment:**

```bash
make reset
```

The reset command removes the base Compose volumes. It is intended for disposable course data.

Integration overlays and the kind cluster have separate lifecycle commands. See the command reference before cleanup.

## Development checks

```bash
go test ./...
go vet ./...
go build ./...
```

Format Go source:

```bash
make fmt
```

Formatting modifies source files.

## Repository layout

| Path | Purpose |
|---|---|
| `cmd/` | Application entry points |
| `internal/` | Application implementation |
| `deployments/` | Docker, Kubernetes, integration, and monitoring configuration |
| `scripts/` | Setup, verification, security, and exercise helpers |
| `fixtures/` | Example transaction payloads |
| `migrations/` | Database schema |
| `schemas/` | Event schemas |
| `security/` | Security-related configuration and assets |
| `streams/` | Stream-processing application |

## Reporting an issue

Include:

1. The command you ran and your working directory.
2. Your operating system and shell.
3. The relevant repository revision.
4. Service status and the relevant log excerpt.
5. Whether you are using the base, integration, security, or Kubernetes environment.

Remove passwords, tokens, and private keys from anything you share.