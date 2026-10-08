package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"

	ledgerkafka "github.com/ledgerflow/ledgerflow/internal/kafka"
)

func main() {
	ctx, cancel := signal.NotifyContext(
		context.Background(),
		syscall.SIGINT,
		syscall.SIGTERM,
	)

	defer cancel()

	brokerEnv := os.Getenv("KAFKA_BROKERS")
	if brokerEnv == "" {
		brokerEnv =
			"localhost:29092,localhost:39092,localhost:49092"
	}

	brokers := strings.Split(
		brokerEnv,
		",",
	)

	inputTopic := os.Getenv(
		"KAFKA_TRANSACTION_TOPIC",
	)
	if inputTopic == "" {
		inputTopic = "ledgerflow.transactions"
	}

	outputTopic := os.Getenv(
		"KAFKA_FRAUD_RESULTS_TOPIC",
	)
	if outputTopic == "" {
		outputTopic = "ledgerflow.fraud-results"
	}

	service, err := ledgerkafka.NewFraudService(
		brokers,
		inputTopic,
		outputTopic,
		"fraud-service",
	)
	if err != nil {
		log.Fatalf(
			"create fraud service: %v",
			err,
		)
	}

	defer service.Close()

	log.Printf(
		"fraud-service consuming %s and producing %s",
		inputTopic,
		outputTopic,
	)

	if err := service.Run(ctx); err != nil {
		log.Fatalf(
			"fraud-service failed: %v",
			err,
		)
	}
}
