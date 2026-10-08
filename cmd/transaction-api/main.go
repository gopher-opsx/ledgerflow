package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ledgerflow/ledgerflow/internal/config"
	"github.com/ledgerflow/ledgerflow/internal/httpapi"
	"github.com/ledgerflow/ledgerflow/internal/kafka"
)

func main() {
	cfg := config.LoadTransactionAPI()

	producer, err := kafka.NewProducer(
		cfg.KafkaBrokers,
		cfg.KafkaTopic,
	)
	if err != nil {
		log.Fatalf(
			"create kafka producer: %v",
			err,
		)
	}

	defer producer.Close()

	server := &http.Server{
		Addr: cfg.HTTPAddr,

		Handler: httpapi.NewRouter(
			producer,
		),

		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(
		chan error,
		1,
	)

	go func() {
		log.Printf(
			"transaction-api listening on %s",
			cfg.HTTPAddr,
		)

		if err := server.ListenAndServe(); err != nil &&
			!errors.Is(
				err,
				http.ErrServerClosed,
			) {
			errCh <- err
		}
	}()

	sigCh := make(
		chan os.Signal,
		1,
	)

	signal.Notify(
		sigCh,
		syscall.SIGINT,
		syscall.SIGTERM,
	)

	select {
	case sig := <-sigCh:
		log.Printf(
			"shutdown signal received: %s",
			sig,
		)

	case err := <-errCh:
		log.Fatalf(
			"http server failed: %v",
			err,
		)
	}

	ctx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)

	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf(
			"graceful shutdown failed: %v",
			err,
		)
	}
}
