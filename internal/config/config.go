package config

import "os"

type TransactionAPI struct {
	HTTPAddr string
}

func LoadTransactionAPI() TransactionAPI {
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	return TransactionAPI{
		HTTPAddr: addr,
	}
}
