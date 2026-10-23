# Decision: Replace three-argument `server.tool()` with `server.registerTool()`

- **Date:** 2026-05-02
- **Project:** swarm-communication-layer
- **Status:** accepted

## Context

During the pid-37584 swarm run (2026-05-02), a bootstrap agent discovered that all tool
calls to the swarm bus were returning wrong or empty results. No errors were thrown and the
tools appeared to register and execute normally. Investigation revealed the root cause was
in how the MCP SDK resolves the handler signature when `inputSchema` is omitted.

## Decision

All MCP tool registrations in `src/server.js` use `server.registerTool()` with an explicit
`inputSchema` parameter:

```js
server.registerTool(
  'tool_name',
  { description: '...', inputSchema: z.object({}).passthrough() },
  async (args) => { /* args is the actual tool input */ }
);
```

`z.object({}).passthrough()` is used as the schema to accept any object without stripping
keys. Each tool handler validates its own specific inputs internally.

The three-argument form `server.tool(name, description, handler)` is banned. It must not
appear in any new tool registration.

## Reasoning

In MCP SDK v1.29+, the three-argument overload of `server.tool()` omits `inputSchema`.
When `inputSchema` is absent the SDK interprets the handler positional arguments differently
and passes the `extra` request metadata object as the first argument instead of the tool's
input arguments. This means `args.to`, `args.from_agent`, etc., are all `undefined` —
every tool silently does nothing or returns wrong data.

The failure mode is invisible:
- The tool registration call succeeds without error
- The handler is invoked without error
- No type error is thrown (the extra object is a valid object)
- The tool returns a result — just the wrong one

This makes the bug nearly impossible to detect from logs alone. It was only caught by
a bootstrap agent performing a live end-to-end smoke test before dispatching the swarm.

Alternatives considered:
- Keep three-argument form and document the behavior: rejected — the footgun is too silent
  and too easy to hit. Any new contributor or agent writing a tool will reach for the
  three-argument form first.
- Use `server.tool(name, schema, handler)` (pass schema as second arg): rejected — the
  `registerTool` API is cleaner and more explicit. Using two different API surfaces
  increases cognitive load.

## Consequences

- All existing tools in `src/server.js` were updated in pid-37584. No handler logic changed.
- New tools added in the future must use `server.registerTool()` — see `shared/conventions.md`
  under "MCP SDK Pitfalls".
- The `passthrough()` schema means Zod does not validate inputs at the registration layer.
  Validation is each handler's responsibility. This is intentional — it keeps the
  registration pattern uniform and avoids schema duplication.

## Supersedes

None. This is a new constraint introduced from the pid-37584 incident.
