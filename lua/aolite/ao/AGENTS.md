### Title

**AOLite Agent Runtime (`lua/aolite/ao`)**

---

### Overview

Small embedded runtime that lets each **AO process** (agent) run user-defined Lua code, exchange signed messages, spawn sub-processes, schedule work, and attach custom handlers — all inside a deterministic, coroutine-driven sandbox.
Core surfaces two primary objects to every script:

* **`ao`** – sandboxed gateway for messaging, spawning, assignment & misc helpers.
* **`Handlers`** – dynamic registry that routes inbound messages (or cron ticks) to user callbacks.

---

### Key Data Structures & Fields

| Structure                                  | Important Fields                                                                                            | Purpose                                                                                            |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| **`ao` object** (created in `ao.lua`)      | `id`, `_module`, `_version`, `authorities`, `outbox { Output, Messages, Spawns, Assignments }`, `reference` | Holds process identity & buffered side-effects until scheduler flushes them.                       |
| **Outbox message / spawn skeleton**        | `Target`, `Data`, `Anchor`, `Tags[] (name,value)`, helpers `onReply`, `receive`                             | Encodes outbound messages; `Anchor` is 32-char zero-padded monotonic counter.                      |
| **`process` runtime** (`process.lua`)      | `Inbox[]`, `_version`, functions `handle`, `clearInbox`, `getMsgs`, `Receive`                               | Per-process coroutine that wraps user code and enforces security / logging.                        |
| **`Handlers` table** (`handlers.lua`)      | `list[]` (each: `name, pattern, handle, maxRuns`), `coroutines[]`, `onceNonce`                              | Central registry; each entry is a router rule + callback.                                          |
| **Assignable registry** (`assignment.lua`) | `ao.assignables[]` (each: `pattern, name`), helpers `addAssignable`, `removeAssignable`                     | Whitelist of match-specs that inbound assignment messages must satisfy.                            |
| **Utility tables**                         | `Colors`, `Utils`, `Handlers.utils`                                                                         | Terminal colors, generic pattern matching, handler helpers (`matchesSpec`, `hasMatchingTag`, etc.) |

---

### Key Functions

| Function                          | File           | Signature / Notes                                                                                                                                           |
| --------------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ao.send`                         | `ao.lua`       | Builds message object, pushes to outbox, returns helpers (`onReply`, `receive`).                                                                            |
| `ao.spawn`                        | `ao.lua`       | Same as `send` but creates “Process” message; returns helpers (`onReply`, `receive`).                                                                       |
| `ao.assign`                       | `ao.lua`       | Queue arbitrary assignment request (`{ Processes, Message }`).                                                                                              |
| `Handlers.add / append / prepend` | `handlers.lua` | Register or update a handler {pattern, callback, maxRuns}.                                                                                                  |
| `Handlers.once`                   | `handlers.lua` | Convenience wrapper => auto-remove after a single match.                                                                                                    |
| `Handlers.receive`                | `handlers.lua` | Coroutine-blocking wait until message matches `pattern`.                                                                                                    |
| `Handlers.evaluate`               | `handlers.lua` | Iterate through registry; invoke matching callbacks; honor `continue/break/skip` codes.                                                                     |
| `process.handle`                  | `process.lua`  | **Entry point executed by scheduler** for every inbound message. Orchestrates boot logic, default handler, security checks and invokes `Handlers.evaluate`. |
| `boot(...)`                       | `boot.lua`     | On first “Process” message: fetch and `eval` source code from `msg.Data` or txId specified in `On-Boot` tag.                                                |
| `ao.clone / normalize / sanitize` | `ao.lua`       | Deep copy, tag extraction, and tag pruning helpers.                                                                                                         |

---

### Relationships

* `process.lua` **injects** `ao` and `Handlers` into the user environment, monkey-patches `ao.send/spawn` to auto-JSON-encode tables, then defers to **handlers** for logic.
* `ao` uses **Handlers** when running inside the runtime (adds receive/onReply), but can run headless (e.g. in tests).
* `boot.lua` is registered by `process.handle` via `Handlers.once("_boot", …)` and runs only once to load user source.
* `assignment.lua` augments the shared `ao` instance with assignable whitelisting helpers that `process.handle` consults during security checks.
* `handlers-utils.lua` piggybacks on `ao` for convenience helpers (`_utils.reply` sends via global `ao`).

---

### Usage Flow

1. **Spawn process**

   ```lua
   ao.spawnProcess("p1","examples.process_template", { {name="On-Boot",value="Data"} })
   ```

   Scheduler delivers a “Process” message → `process.handle` boots user code.
2. **Register handlers** inside user script with `Handlers.add/once`.
3. **Send message** via `ao.send{ Target="p1", Action="Ping" }` — placed in outbox then delivered.
4. **Scheduler** dequeues message → `process.handle` → `Handlers.evaluate` routes to proper callback.
5. **Callback** can reply with `msg.reply({...})`, forward, spawn, or queue further work; all side-effects accumulate in `ao.outbox`.
6. **Scheduler flushes** outbox to global message bus, repeats.
7. **Receive blocking** inside script possible via `Handlers.receive(pattern)` (internally yields coroutine).
8. **Process termination / cleanup** handled by environment (not in this module).

---

### File Summaries

| File                 | Main Responsibility                                                                            | Important APIs                                                       |
| -------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `process.lua`        | Core per-process runtime wrapper; security, inbox, eval, logging.                              | `process.handle`, `Receive`, `getMsgs`, `clearInbox`.                |
| `ao.lua`             | Construct sandboxed **ao** interface → messaging, spawning, assignments, outbox mgmt, helpers. | `send`, `spawn`, `assign`, `normalize`, `sanitize`.                  |
| `boot.lua`           | One-shot boot loader that executes user code supplied via `On-Boot` tag or txId.               | Returned boot function.                                              |
| `default.lua`        | Fallback handler that prints any unmatched message.                                            | Simple colorized logging.                                            |
| `assignment.lua`     | Extends `ao` with assignable whitelist & helper predicates.                                    | `addAssignable`, `removeAssignable`, `isAssignment`, `isAssignable`. |
| `handlers.lua`       | Dynamic router registry; coroutine-aware receive; once; evaluate loop.                         | `add`, `append`, `prepend`, `once`, `receive`, `remove`, `evaluate`. |
| `handlers-utils.lua` | Misc pattern helpers reused by handlers.                                                       | `matchesSpec`, `hasMatchingTag`, `reply`, `continue`.                |

---

### Typical Agent Skeleton

```lua
local ao = require("aolite")

Handlers.add("Ping", "Ping", function(msg)
  print("got ping")
  msg.reply{ Action="Pong" }
end)

Handlers.add("OnBoot", function(msg) return msg.Tags.OnBoot == "Data" end, function()
  print("booted: " .. ao.id)
end)

-- long-running coroutine waiting for external trigger
ao.send{ Target=ao.id, Action="Ping" }
local resp = Handlers.receive{ Action="Pong" }    -- blocks
print("received", resp.Action)
```

An LLM can now reconstruct full agent behavior, extend the runtime, or generate new processes using only the abstractions documented above.
