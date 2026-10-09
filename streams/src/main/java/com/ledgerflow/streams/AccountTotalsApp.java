package com.ledgerflow.streams;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Produced;

import java.math.BigDecimal;
import java.util.Properties;

public final class AccountTotalsApp {
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
                inputTopic,
                Consumed.with(Serdes.String(), Serdes.String()));

        transactions
                .mapValues(AccountTotalsApp::toAmount)
                .groupByKey()
                .reduce(BigDecimal::add)
                .toStream()
                .mapValues(BigDecimal::toPlainString)
                .to(outputTopic, Produced.with(Serdes.String(), Serdes.String()));

        KafkaStreams streams = new KafkaStreams(builder.build(), props);
        Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
        streams.start();
    }

    private static BigDecimal toAmount(String json) {
        try {
            JsonNode node = MAPPER.readTree(json);
            return node.path("amount").decimalValue();
        } catch (Exception e) {
            throw new IllegalArgumentException("invalid transaction JSON", e);
        }
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }
}
