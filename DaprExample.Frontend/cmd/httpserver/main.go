package main

import (
	"net/http"
	"strings"

	// Uncomment below when profiling is needed
	//_ "net/http/pprof"

	"github.com/cloudwithchris/event-platform/api/redirect/internal/handlers"
	"github.com/gorilla/mux"
)

func main() {
	redirectHandler := handlers.NewHttpHandler()

	router := mux.NewRouter()
	router.HandleFunc("/name", redirectHandler.Get).Methods("GET")

	// Start the server
	http.ListenAndServe(":6002", removeTrailingSlashes(router))
}

func removeTrailingSlashes(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.URL.Path = strings.TrimSuffix(r.URL.Path, "/")
		// Call the next handler, which can be another middleware in the chain, or the final handler.
		next.ServeHTTP(w, r)
	})
}
