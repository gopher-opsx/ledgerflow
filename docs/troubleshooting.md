# Troubleshooting and shell guide

Use this sequence:

1. Identify the symptom.
2. Identify the affected request or event path.
3. Collect evidence.
4. Form a specific hypothesis.
5. Test one change.
6. Apply the fix.
7. Verify the full path and recovery.

Avoid resetting the environment before collecting evidence.

## Shell differences

The repository helper scripts are Bash scripts.

| Feature | Bash / Git Bash | PowerShell |
|---|---|---|
| Session environment variable | `export NAME=value` | `$env:NAME = "value"` |
| Variable reference | `$NAME` | `$env:NAME` for an environment variable |
| Line continuation | Backslash `\` | Backtick |
| Run a Bash script | `bash scripts/smoke-test.sh` | Requires an installed Bash environment |
| HTTP CLI | `curl` | Use `curl.exe` on Windows for curl syntax |
| Current directory | `pwd` | `Get-Location` |

Linux is an operating-system family. Bash is a shell. Linux users may use Bash or another shell.

Git Bash provides Bash and Unix-style tools on Windows. It does not turn Windows into Linux.

WSL provides a Linux environment on Windows. Docker access depends on the installed engine and WSL integration configuration.

### Recommended approach

Use one shell consistently for each exercise.

- Use Bash, Git Bash, or configured WSL for the repository scripts.
- Use PowerShell for native Docker or kubectl commands when convenient.
- Do not paste multiline Bash syntax directly into PowerShell.
- Run commands from the repository root.

### Git Bash path conversion

Symptoms can include a container path unexpectedly rewritten to a Windows path.

For the current Git Bash session:

```bash
export MSYS_NO_PATHCONV=1
```

For one command:

```bash
MSYS_NO_PATHCONV=1 docker exec ledgerflow-broker-1 \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server broker-1:19092 \
  --list
```

This workaround is for Git Bash path conversion. It is not normally required on Linux.

### PowerShell curl example

```powershell
curl.exe -i -H "Content-Type: application/json" --data-binary "@fixtures/transaction-approved.json" http://localhost:8080/api/v1/transactions
```

The quoted `@...` argument tells curl to read the request body from a file.

### Make is missing

Git Bash does not necessarily include GNU Make.

Use the direct helper:

```bash
bash scripts/init-topics.sh
bash scripts/smoke-test.sh
```

Or install GNU Make in your chosen environment.

### Script permissions

On Linux or WSL, a script may need its executable bit:

```bash
chmod +x scripts/init-topics.sh
```

Alternatively:

```bash
bash scripts/init-topics.sh
```

A helper may invoke other scripts directly, so executable permissions may still matter for nested calls.

### Windows line endings

Errors such as `bash\r`, `$'\r': command not found`, or `bad interpreter` can indicate CRLF line endings.

Save shell scripts with LF endings.

Avoid bulk line-ending conversion across unrelated repository files.

## Docker engine unavailable

Check:

```bash
docker version
docker info
```

If only client information is available, start or reconnect to the Docker engine.

On Docker Desktop, confirm that the engine is running and that the intended Linux-container environment is selected.

## Compose configuration or startup failure

Validate configuration:

```bash
docker compose -f deployments/docker/compose.kafka.yaml config --quiet
```

Inspect services:

```bash
docker compose -f deployments/docker/compose.kafka.yaml ps -a
```

Read logs:

```bash
docker compose -f deployments/docker/compose.kafka.yaml logs --tail=150
```

An initialisation container that exits with status zero can be expected. A broker or application repeatedly restarting requires investigation.

## Image pull denied

Check the full image name and registry in the Compose file.

Possible causes include:

- Registry authentication is required.
- The image tag is unavailable.
- Network or proxy access failed.
- The account lacks access.

Authenticate to the registry specified by the image when required. Rebuilding application images will not fix registry authentication.

## Port already allocated

Inspect running containers:

```bash
docker ps
```

Find the conflicting service before stopping it.

Changing a published port may also require updating URLs, client bootstrap addresses, or advertised listener configuration.

## API unavailable

```bash
docker compose -f deployments/docker/compose.kafka.yaml ps -a
docker compose -f deployments/docker/compose.kafka.yaml logs --tail=100 transaction-api
curl -i http://localhost:8080/health/live
curl -i http://localhost:8080/health/ready
```

Check whether the API is listening, whether dependencies are ready, and whether the host port is mapped as expected.

Liveness and readiness answer different questions.

## API accepts a request but no ledger record appears

Inspect the processing path:

1. API publish result.
2. Transaction topic.
3. Ledger consumer membership and lag.
4. Ledger Service logs.
5. PostgreSQL availability and write errors.

Commands:

```bash
make inspect-groups
docker compose -f deployments/docker/compose.kafka.yaml logs --tail=150 ledger-service postgres
```

An accepted API response is not proof of completed downstream processing.

## Kafka bootstrap or hostname failure

Distinguish where the client runs:

| Client location | Address type |
|---|---|
| Inside the Compose network | Docker service DNS and internal listener |
| On the host | Published host listener |
| Inside Kubernetes | Kubernetes service DNS and configured listener |

A bootstrap connection is only the first step. Kafka returns broker addresses in metadata, and those addresses must also be reachable.

Do not replace every broker address with `localhost`; inside a container, `localhost` refers to that container.

## Missing topic

List topics:

```bash
docker exec ledgerflow-broker-1 \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server broker-1:19092 \
  --list
```

For the base environment, initialise topics after Kafka is ready:

```bash
make topics
```

If using security, use the matching authenticated client configuration.

## Consumer lag remains high

Check:

- The consumer is running and joined to the intended group.
- The group ID is correct.
- Records are arriving faster than processing.
- Database calls or downstream services are slow.
- The consumer is repeatedly failing or rebalancing.
- Partition count limits useful consumer concurrency.

```bash
make inspect-groups
docker compose -f deployments/docker/compose.kafka.yaml logs --tail=150 ledger-service
```

Adding a different consumer group creates an independent subscription. It does not share the existing group's backlog.

To share work, consumers must join the same group; useful partition-processing concurrency is bounded by the topic's partition assignment.

## ISR does not recover

Restore stopped brokers:

```bash
docker compose -f deployments/docker/compose.kafka.yaml start broker-2 broker-3
```

Inspect broker logs and describe the topic.

Container startup does not mean replica catch-up is complete.

Do not weaken durability settings merely to make a failure exercise pass.

## Grafana shows no data

Check in order:

1. Correct datasource.
2. Correct dashboard time range.
3. Prometheus target health.
4. Whether the metric exists in Prometheus.
5. Whether required recording rules exist.
6. Dashboard variables, labels, and query errors.

A dashboard can be empty while Prometheus is healthy if the query expects missing rules or different labels.

JMX Exporter and Kafka Exporter expose different metric families. Confirm which exporter supplies the query.

## TLS trust failure

For errors such as `PKIX path building failed`, inspect:

- The CA trusted by the client.
- The certificate chain supplied by the broker.
- The mounted truststore or CA file.
- The client properties file actually in use.

For hostname-verification failures, compare the connection hostname with the certificate's Subject Alternative Names.

Check certificate validity dates and system time.

Do not disable verification as the final fix.

## SASL authentication failure

Verify:

- The listener uses the intended security protocol.
- Client and broker SASL mechanisms match.
- The username and password are correct.
- Broker authentication configuration is loaded.
- The client is using the intended configuration file.

TLS trust, SASL authentication, and ACL authorisation are separate checks.

## ACL failure

Distinguish:

- Authentication failed.
- Authentication succeeded but authorisation was denied.
- The broker has no authorizer configured.

For `SecurityDisabledException: No Authorizer`, enable the intended authorizer in the broker configuration and restart through the matching security workflow.

Check the authenticated principal, resource names, operations, group permissions, and administrative credentials.

Applying ACLs does not itself enable the authorizer.

## Idempotency verification fails

Inspect the event and transaction identifiers used by the exercise.

For one deliberately duplicated event, the expected durable counts are:

```text
transactions=1
ledger_entries=2
processed_events=1
```

Check consumer logs, database constraints, transaction boundaries, and processing completion.

Do not compare whole-table counts in a database containing earlier exercise records.

## Dead-letter record missing

Check:

- The malformed record reached the source topic.
- The intended consumer is running.
- The consumer encountered the record.
- The configured dead-letter topic name.
- Permission to publish to the dead-letter topic.
- Errors in dead-letter publication.

A failed application is not proof that a record was safely routed to a dead-letter topic.

## Kafka Connect task failed

```bash
curl --fail \
  http://localhost:8083/connectors/ledgerflow-postgres-cdc/status
```

Inspect each task's state and error trace.

Check PostgreSQL connectivity, logical-replication configuration, connector settings, database permissions, and Kafka connectivity.

Connector status alone is insufficient when its task has failed.

## MirrorMaker topic exists but data is missing

Use a new transaction identifier and verify the corresponding record at the destination.

Check source and destination connectivity, replication configuration, task status, and topic naming.

Topic existence alone does not prove record replication.

## Kubernetes command targets the wrong cluster

Before applying changes:

```bash
kubectl config current-context
kubectl config get-contexts
```

For the course cluster:

```bash
kubectl config use-context kind-ledgerflow
```

Verify context again before destructive commands.

## Pod is Pending

```bash
kubectl get pods,pvc -n ledgerflow
kubectl describe pod POD_NAME -n ledgerflow
kubectl get events -n ledgerflow --sort-by=.lastTimestamp
```

Check resource capacity, scheduling constraints, storage provisioning, and image availability.

## ImagePullBackOff

Check the image name and tag, registry access, and whether the image was loaded into the correct kind cluster.

For locally built application images:

```bash
make k8s-load-apps
```

Inspect the deployment's image pull policy as well as its image name.

## CrashLoopBackOff

```bash
kubectl logs POD_NAME -n ledgerflow
kubectl logs POD_NAME -n ledgerflow --previous
kubectl describe pod POD_NAME -n ledgerflow
```

Replace `POD_NAME` with the actual name.

Inspect startup configuration, dependency addresses, credentials, probes, and termination reasons.

## Recover before resetting

After restoring the failed component:

```bash
make inspect-groups
make smoke
```

For Kubernetes, inspect workload readiness and verify application processing through the Kubernetes environment.

Reset only when you deliberately want a fresh disposable environment. Resetting deletes evidence and may delete data needed for diagnosis.