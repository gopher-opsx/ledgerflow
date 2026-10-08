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
		"KAFKA_NOTIFICATIONS_TOPIC",
	)
	if outputTopic == "" {
		outputTopic = "ledgerflow.notifications"
	}

	service, err :=
		ledgerkafka.NewNotificationService(
			brokers,
			inputTopic,
			outputTopic,
			"notification-service",
		)

	if err != nil {
		log.Fatalf(
			"create notification service: %v",
			err,
		)
	}

	defer service.Close()

	log.Printf(
		"notification-service consuming %s and producing %s",
		inputTopic,
		outputTopic,
	)

	if err := service.Run(ctx); err != nil {
		log.Fatalf(
			"notification-service failed: %v",
			err,
		)
	}
}
