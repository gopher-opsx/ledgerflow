package config

import (
	"os"
	"strings"
)

type TransactionAPI struct {
	HTTPAddr     string
	KafkaBrokers []string
	KafkaTopic   string
}

func LoadTransactionAPI() TransactionAPI {
	httpAddr := os.Getenv("HTTP_ADDR")
	if httpAddr == "" {
		httpAddr = ":8080"
	}

	brokers := os.Getenv("KAFKA_BROKERS")
	if brokers == "" {
		brokers = "localhost:29092,localhost:39092,localhost:49092"
	}

	topic := os.Getenv("KAFKA_TRANSACTION_TOPIC")
	if topic == "" {
		topic = "ledgerflow.transactions"
	}

	return TransactionAPI{
		HTTPAddr:     httpAddr,
		KafkaBrokers: strings.Split(brokers, ","),
		KafkaTopic:   topic,
	}
}
