package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/ledgerflow/ledgerflow/internal/database"
	ledgerkafka "github.com/ledgerflow/ledgerflow/internal/kafka"
)

func main() {
	ctx, cancel := signal.NotifyContext(
		context.Background(),
		syscall.SIGINT,
		syscall.SIGTERM,
	)

	defer cancel()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		databaseURL =
			"postgres://ledgerflow:ledgerflow@localhost:5432/ledgerflow?sslmode=disable"
	}

	brokerEnv := os.Getenv("KAFKA_BROKERS")
	if brokerEnv == "" {
		brokerEnv =
			"localhost:29092,localhost:39092,localhost:49092"
	}

	brokers := strings.Split(
		brokerEnv,
		",",
	)

	topic := os.Getenv("KAFKA_TRANSACTION_TOPIC")
	if topic == "" {
		topic = "ledgerflow.transactions"
	}

	dltTopic := os.Getenv("KAFKA_DLT_TOPIC")
	if dltTopic == "" {
		dltTopic = "ledgerflow.transactions.dlt"
	}

	db, err := database.New(
		ctx,
		databaseURL,
	)
	if err != nil {
		log.Fatalf(
			"connect postgres: %v",
			err,
		)
	}

	defer db.Close()

	consumer, err :=
		ledgerkafka.NewTransactionConsumer(
			brokers,
			topic,
			"ledger-service",
			dltTopic,
			3,
			db,
		)

	if err != nil {
		log.Fatalf(
			"create transaction consumer: %v",
			err,
		)
	}

	defer consumer.Close()

	log.Printf(
		"ledger-service consuming topic %s",
		topic,
	)

	if err := consumer.Run(ctx); err != nil {
		log.Fatalf(
			"ledger-service failed: %v",
			err,
		)
	}
}
