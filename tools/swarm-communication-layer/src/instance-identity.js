/**
 * instance-identity.js — runtime-resolved bus-instance identity
 * ESM module
 *
 * The actual bound port is only known after bindExclusive() resolves at
 * startup (server.js), but response.js (imported by every tool handler)
 * needs to read it. This tiny leaf module exists specifically to avoid a
 * circular import: server.js -> mcp-server.js -> tool files -> response.js
 * would need to import back into server.js if the getter lived there.
 */

let resolvedPort = null;

export function setResolvedPort(port) {
  resolvedPort = port;
}

export function getResolvedPort() {
  return resolvedPort;
}
