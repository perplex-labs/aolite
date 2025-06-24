### Title

**AOLite Factories — Sandboxed Wrappers for Up-Stream Runtime (`lua/aolite/factories`)**

---

### Overview

The *factories* folder houses **three adapter modules** that instantiate the
original AO runtime modules (vendored in `lua/aos/process`) inside an isolated
Lua environment.  Each AO *process* therefore executes its own private copy of
`ao`, `Handlers` and `Process`, keeping globals, random seeds, and message
queues fully sandboxed while still running in a single Lua VM.

These wrappers are the bridge between AOLite's public API and the authoritative
implementation maintained upstream; they rely heavily on the compatibility
layer defined in `aolite/compat.lua` (dual-`require`) to resolve module names
and to execute code in a caller-supplied environment.

---

### Key Modules & Responsibilities

| File                     | Exports (primary)          | Purpose & Notes |
| ------------------------ | -------------------------- | --------------- |
| **`ao.lua`**             | `createAO(Handlers)`       | Builds a fresh sandbox, loads `aos.process.ao`, initialises assignment helpers, returns the new AO table. |
| **`handlers.lua`**       | `createHandlers(pid)`      | Executes upstream `aos.process.handlers` in its own env so every process keeps an independent handler list. |
| **`process.lua`**        | `createProcess(ao, Handlers)` | Runs `aos.process.process` inside a sandbox bound to the supplied `ao` & `Handlers`.  Adds back-compat helpers `getMsgs`, `clearInbox`, and wraps `handle()` to mirror inbox/outbox into AOLite's global stores. |

---

### Typical Invocation Sequence

1. `aolite.process.spawnProcess` (see `lua/aolite/process.lua`) is called by
   the public API.
2. It calls **`createHandlers(pid)`** to obtain an isolated `Handlers` table.
3. Passes `Handlers` into **`createAO`** which returns a sandboxed `ao` table.
4. Both are sent to **`createProcess(ao, Handlers)`** yielding the final
   `Process` module whose `handle()` coroutine is registered with the
   scheduler.

The three factories therefore cooperate to deliver a fully-functioning yet
hermetically-sealed AO runtime for every simulated process.

---

### Environment Layout (per factory)

* `env._G` / `env._ENV` → sandbox global table.
* `env.package.loaded`  → pre-seeded with already-built modules so nested
  `require()` calls deduplicate work.
* `env.require(mod)`    → first checks `env.package.loaded`, then delegates to
  the **dual-require** from `aolite/compat.lua`, passing the same `env` so
  downstream loads stay inside the sandbox.

---

### Notable Helpers Added by `process.lua`

* **`getMsgs(matchSpec, fromFirst?, count?)`** – scans the sandbox inbox using
  upstream `utils.matchesSpec`; returns a slice matching the predicate.
* **`clearInbox()`** – empties the sandbox inbox and the parent's stored copy.
* **`handle(msg, _)` (wrapped)** – intercepts each inbound message to:
  1. keep an authoritative inbox in `env.Inbox`,
  2. duplicate self-addressed outbox messages back into that inbox, and
  3. mirror every generated message/spawn/assignment into AOLite's
     `env.messageStore` for global introspection.

---

### Relationships

* All three factories depend on `compat.resolveModulePath` (via
  `dualRequire`) to translate friendly dots (`.ao`, `.handlers`, `.utils`,
  `.crypto.*`, etc.) into concrete upstream paths (`aos.process.*`).
* The returned tables are cached in `env.package.loaded` so that successive
  imports of the *same* name within the sandbox yield the original instance.
* Factories are *stateless* – you call them once per AO process; the resulting
  objects hold all the state.

---

### Testing

The factories are exercised indirectly by the normal test-suite:

```bash
make test
```

which spawns multiple processes, sends messages and evaluates code to ensure
sandbox isolation works correctly. 