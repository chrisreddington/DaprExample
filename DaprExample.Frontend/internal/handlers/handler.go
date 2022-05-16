package handlers

import (
	"encoding/json"
	"net/http"
	"os"
	//"go.opentelemetry.io/otel/attribute"
	//"go.opentelemetry.io/otel/trace"
)

// name is the Tracer name used to identify this instrumentation library.
const name = "hostnameservice"

type HttpHandler struct {
}

func NewHttpHandler() *HttpHandler {
	return &HttpHandler{}
}

// swagger:route GET / string get-url
//
// Redirects the user from domain/redirect/shortUrl to the associated destinationUrl address.
//
// responses:
//   200: RedirectResponseObject
//   404: genericError
//	 500: genericError
func (handler *HttpHandler) Get(res http.ResponseWriter, req *http.Request) {

	// Get the hostname of the running container
	name, err := os.Hostname()
	if err != nil {
		panic(err)
	}

	// Convert the OS Hostname into a JSON object
	jsonResp, err := json.Marshal(name)
	if err != nil {
		http.Error(res, err.Error(), http.StatusBadRequest)
		return
	}

	res.Write(jsonResp)
	res.WriteHeader(http.StatusOK)
	return
}
