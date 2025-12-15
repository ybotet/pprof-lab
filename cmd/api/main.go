package main

import (
	"fmt"
	"log"
	"net/http"
	_ "net/http/pprof"
	"time"

	"github.com/ybotet/pprof-lab/internal/work"
)

func main() {
	mux := http.NewServeMux()

	// Endpoint con versión LENTA (para comparación)
	mux.HandleFunc("/work-slow", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		n := 45
		res := work.Fib(n) // Versión lenta
		elapsed := time.Since(start)

		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprintf(w, "Fib(%d) = %d\nTiempo: %v\n", n, res, elapsed)
		log.Printf("SLOW: Fib(%d) tomó %v", n, elapsed)
	})

	// Endpoint con versión RÁPIDA
	mux.HandleFunc("/work-fast", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		n := 45
		res := work.FibFast(n) // Versión optimizada
		elapsed := time.Since(start)

		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprintf(w, "FibFast(%d) = %d\nTiempo: %v\n", n, res, elapsed)
		log.Printf("FAST: FibFast(%d) tomó %v", n, elapsed)
	})

	// Endpoint principal que usa la versión rápida
	mux.HandleFunc("/work", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		n := 45
		res := work.FibFast(n) // Usamos la versión optimizada
		elapsed := time.Since(start)

		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprintf(w, "FibFast(%d) = %d\nTiempo: %v\n", n, res, elapsed)
	})

	// Registrar handlers de pprof
	mux.HandleFunc("/debug/pprof/", func(w http.ResponseWriter, r *http.Request) {
		http.DefaultServeMux.ServeHTTP(w, r)
	})

	log.Println(" Servidor iniciado en :8082")
	log.Println(" PPROF: http://localhost:8082/debug/pprof/")
	log.Println(" Lento: http://localhost:8082/work-slow")
	log.Println(" Rápido: http://localhost:8082/work-fast")
	log.Println(" Principal: http://localhost:8082/work")

	log.Fatal(http.ListenAndServe(":8082", mux))
}
