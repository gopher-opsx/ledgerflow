// LedgerFlow Lesson 25: continuously calculate totals from Kafka transaction events.
// Invalid or unrelated test messages are skipped, not allowed to stop the pipeline.
// Totals are sums of transaction amounts, NOT real banking account balances.
// Kafka Streams' exactly-once setting covers Kafka processing, not external databases.
package com.ledgerflow.streams;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.Grouped;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Produced;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;
import java.util.Properties;

public final class AccountTotalsApp {
    private static final Logger LOG = LoggerFactory.getLogger(AccountTotalsApp.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private AccountTotalsApp() {}

    public static void main(String[] args) {
        String brokers = env("KAFKA_BROKERS", "broker-1:19092,broker-2:19092,broker-3:19092");
        String inputTopic = env("INPUT_TOPIC", "ledgerflow.transactions");
        String outputTopic = env("OUTPUT_TOPIC", "ledgerflow.account-totals");
        String applicationId = env("APPLICATION_ID", "ledgerflow-account-totals");

        Properties props = new Properties();
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, applicationId);
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, brokers);
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
        props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2);

        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, String> transactions = builder.stream(
                inputTopic, Consumed.with(Serdes.String(), Serdes.String()));

        // Extract account_id from the JSON itself instead of assuming the
        // original Kafka record key contains the account ID.
        // flatMap emits ONE valid record, or ZERO records for malformed input.
        // We use Strings for the amount in Kafka state/output; BigDecimal is
        // used for arithmetic to avoid floating-point rounding mistakes.
        transactions
                .flatMap((originalKey, json) -> parseTransaction(json))
                .groupByKey(Grouped.with(Serdes.String(), Serdes.String()))
                .reduce((previous, incoming) ->
                        new BigDecimal(previous).add(new BigDecimal(incoming)).toPlainString())
                .toStream()
                .to(outputTopic, Produced.with(Serdes.String(), Serdes.String()));

        KafkaStreams streams = new KafkaStreams(builder.build(), props);

        // A bad record is handled above. Other failures should still be visible
        // in the logs and investigated rather than silently ignored.
        streams.setUncaughtExceptionHandler(exception -> {
            LOG.error("Unexpected Kafka Streams failure", exception);
            return org.apache.kafka.streams.errors.StreamsUncaughtExceptionHandler.StreamThreadExceptionResponse.SHUTDOWN_CLIENT;
        });

        Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
        LOG.info("Starting LedgerFlow Streams: {} -> {}", inputTopic, outputTopic);
        streams.start();

        // Keep the Docker container's main Java process running.
        try {
            Thread.currentThread().join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            streams.close();
        }
    }

    private static List<KeyValue<String, String>> parseTransaction(String json) {
        try {
            if (json == null || json.isBlank()) {
                LOG.warn("Skipping empty transaction event");
                return Collections.emptyList();
            }

            JsonNode event = MAPPER.readTree(json);
            JsonNode accountNode = event.path("account_id");
            JsonNode amountNode = event.path("amount");

            // Only application transaction JSON is valid input for this lab.
            if (!event.isObject() || !accountNode.isTextual()
                    || accountNode.asText().isBlank() || !amountNode.isNumber()) {
                LOG.warn("Skipping event without a valid account_id and numeric amount");
                return Collections.emptyList();
            }

            BigDecimal amount = amountNode.decimalValue();
            if (amount.signum() <= 0) {
                LOG.warn("Skipping transaction with non-positive amount for account {}", accountNode.asText());
                return Collections.emptyList();
            }

            return List.of(KeyValue.pair(accountNode.asText(), amount.toPlainString()));
        } catch (Exception e) {
            // Earlier load-test lessons wrote non-JSON data to this same topic.
            // Log and skip those records instead of crashing the entire app.
            LOG.warn("Skipping malformed transaction event: {}", e.getMessage());
            return Collections.emptyList();
        }
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }
}
