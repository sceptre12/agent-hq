// Tracks in-flight HTTP requests and coordinates the graceful-shutdown drain
// (see the SIGTERM handler in server.js). Extracted from server.js — same
// module-level state and logic, just relocated behind a small function API
// so server.js doesn't own mutable shutdown state directly.

let inFlightCount = 0;
let shuttingDown = false;
const inFlightDrainCallbacks = new Set();

export function trackRequest(res) {
  if (shuttingDown) {
    res.writeHead(503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: { code: 'SERVER_SHUTTING_DOWN', message: 'Server is shutting down.' } }));
    return false;
  }
  inFlightCount++;
  res.on('finish', () => {
    inFlightCount--;
    if (shuttingDown && inFlightCount === 0) {
      inFlightDrainCallbacks.forEach((cb) => cb());
    }
  });
  return true;
}

export function beginShutdown() {
  shuttingDown = true;
}

export function getInFlightCount() {
  return inFlightCount;
}

export function onDrain(cb) {
  inFlightDrainCallbacks.add(cb);
}
