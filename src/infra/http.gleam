// src/infra/http.gleam
// Mist router and server wiring. This file mounts slice handlers and starts
// the Mist server. Replace Mist calls with actual imports when available.

pub type Router

pub fn new_router() -> Router {
  // TODO: Create and return a Mist router
  { }
}

pub fn start(_router: Router) {
  // TODO: Start Mist server listening on a port (e.g., from env PORT)
  io.println("Starting Mist server (TODO: implement server start)")
}
