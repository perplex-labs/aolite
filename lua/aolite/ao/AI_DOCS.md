**TITLE**: AO Local Test Environment

**OVERVIEW**
This codebase provides a **local, concurrent** emulation of the AO protocol for testing. Processes run in Lua coroutines, each with an **inbound queue** of message IDs. Each process’s “AO runtime” handles outboxes (messages, spawns, assignments) and the environment provides message flow, concurrency scheduling, and message storage. 

---

## KEY DATA STRUCTURES

1. **`env`** (in `local_env.lua`):
   - **`processes`**: Map processId → { process, ao, Handlers, env }.
   - **`coroutines`**: Map processId → coroutine. Each process runs in its own coroutine.
   - **`queues`**: Map processId → array of message IDs (inbound queue).
   - **`messageStore`**: Map messageId → full message object.
   - **`ready`**: Set of processIds that have messages and need scheduling.
   - **`processed`**: Optional map messageId → boolean if a message was processed.

2. **`process`** (in `local_process.lua`):
   - Main concurrency logic: spawns new processes, enqueues inbound messages, calls `deliverOutbox()` after each message.
   - **`spawnProcess(env, originalId, dataOrPath, initEnv)`**: Creates a new process, sets up its own coroutine `processLoop`.
   - **`deliverOutbox(env, fromId, parentMsgId?)`**: Moves the outbox items (`Messages`, `Spawns`, `Assignments`) to target inbound queues.
   - **`addMsgToQueue(env, msg, sourceId, parentMsgId?)`**: Helper to put a single message into the target queue.

3. **`ao`** (in `ao.lua`):
   - The “AO runtime object” for each process, with:
     - `id`, `_module`: identity.
     - `outbox`: { Messages, Spawns, Assignments }.
     - `send`, `spawn`, `assign`: produce outbox items.
     - `clearOutbox`, `normalize`, `sanitize`, `isTrusted`, `isAssignable`, etc.

4. **`Handlers`** (in `handlers.lua`):
   - A dynamic list of message handlers, each with `pattern`, `handle(msg)`.
   - On message arrival, `Handlers.evaluate(msg, env)` matches the message to a handler.
   - Provides methods like `add`, `once`, `remove`, `receive`, etc.

5. **`scheduler`** (in `local_scheduler.lua`):
   - **`run(env)`**: Simple round-robin approach. Resumes coroutines for all “ready” processes until no more messages remain or `maxCycles` is reached.

6. **`api`** (in `local_api.lua`):
   - Exports user-friendly methods for sending messages, retrieving messages, or performing an eval.
   - **`send(env, msg, clearInbox)`**: Enqueues a message ID in the target’s queue, runs `scheduler.run()`.
   - **`eval(env, processId, expression)`**: Sends an “EvalRequest,” blocks until it sees “EvalResponse,” returns the deserialized result.

7. **`local.lua`**:
   - Orchestrator for tests. Exposes `spawnProcess`, `send`, `eval`, etc.
   - **`clearAllProcesses()`**: Wipes all environment data structures, removing processes/coroutines/queues.

8. **`process.lua`**:
   - An older “process” builder used by `createProcess(ao, Handlers)`.
   - Defines an inbox-based approach (`Inbox`, `handle(msg)`).
   - In concurrency mode, typically overshadowed by `local_process.lua`, but still used to unify message handling with `Handlers.evaluate`.

9. **`serialize.lua`**:
   - **`serializeValue(obj)`** recursively serializes nested tables, bigints, etc.
   - **`reconstructValue(obj)`** reverses that.

10. **Eval** and **Default**
    - **`local_eval.lua`** or `myevalexp.lua`: Provide “EvalRequest” → “EvalResponse” logic.
    - **`default.lua`**: A fallback handler that logs unhandled messages.

---

## KEY FUNCTIONS

1. **`M.spawnProcess(originalId, dataOrPath, tags)`** (in `local.lua`)
   - Calls `process.spawnProcess` to create a new AO process plus a coroutine.

2. **`M.send(msg, clearInbox)`** (in `local.lua` → `api.send`)
   - Ensures `msg.From` is valid, calls `ao.send(msg)`, then enqueues `msg.Id` in the target queue, and triggers `scheduler.run`.

3. **`M.getFirstMsg` / `M.getLastMsg`**
   - Looks inside the target process’s `Inbox` to find matching messages (by a spec of fields like `Action`).

4. **`M.eval(processId, expression)`**
   - Sends an “EvalRequest,” awaits “EvalResponse,” returns the final `.Data`.

5. **`clearAllProcesses()`**
   - Empties `env.processes`, `env.coroutines`, `env.queues`, `env.messageStore`, `env.ready`, etc., removing all concurrency state.

6. **`scheduler.run(env)`**
   - Gathers all `env.ready` processes, resumes each coroutine once if it’s “suspended.”
   - Continues until no more processes do work or `maxCycles` is reached.

7. **`local_process.spawnProcess(env, originalId, dataOrPath, initEnv)`**
   - Creates a new process ID, sets up `Handlers` + `ao`, a `processEnv` table.
   - Defines a coroutine `processLoop` that:
     - Repeatedly pulls message IDs from `env.queues[processId]`.
     - For each message, calls `processModule.handle(msg, processEnv)` and then `deliverOutbox`.

8. **`process.addMsgToQueue(env, msg, sourceId, parentMsgId)`**
   - Ensures standard fields (`From`, `Owner`, `Timestamp`, `Pushed-For`, etc.) and places `msg.Id` in the target’s inbound queue, marking that process “ready.”

---

## RELATIONSHIPS

- **`local.lua`** is the top-level test harness entry.
- **`local_api.lua`** depends on `scheduler.run` to process concurrency.
- **`local_process.lua`** coordinates spawning a process’s coroutine loop.
- **`process.lua`** finalizes how messages are handled internally by `Handlers.evaluate`.
- **`ao.lua`** is embedded in each process object, storing outbox items.
- **`handlers.lua`** is called from each process’s `.handle(msg)` to match messages.
- **`local_scheduler.lua`** picks which coroutines to resume.
- **`serialize.lua`** or `local_eval_exp.lua` handle special tasks like serialization or code eval.

---

## USAGE FLOW

1. **Initialize**: Call `spawnProcess("Core", ...)` to create the first “Core” process.
2. **Send**: `send({From="Core", Target="Acc1", Action="Add-Collateral"})`. This places the message ID in `Acc1`’s queue, runs the scheduler.
3. **Scheduler**: Resumes the “Acc1” coroutine. Acc1 loads the message, calls `Handlers.evaluate(msg)`, processes logic, and if it spawns or sends new messages, they are enqueued.
4. **Eval**: `eval("Core", "return _G.someVar")` sends “EvalRequest,” finds the “EvalResponse,” decodes the data.
5. **Message Handling**: Each process uses `processModule.handle(msg)` (from `process.lua`) to interpret messages, possibly producing outbox “Messages,” “Spawns,” or “Assignments.”
6. **Assignments**: If a message is assigned to multiple processes, each is queued with the same message ID from `messageStore`.
7. **Clearing**: If you want to remove everything, call `clearAllProcesses()`.

---

## FILE SUMMARIES

- **`local.lua`**: Main test interface. Exposes `spawnProcess, send, getFirstMsg, getLastMsg, eval, clearAllProcesses`.
- **`local_env.lua`**: Creates the environment object with `processes, coroutines, queues, messageStore, ready`.
- **`local_process.lua`**: Spawns new processes (coroutines) and handles outbox delivery.
- **`process.lua`**: Defines `createProcess(ao, Handlers)` → a `process` object with `.handle(msg)`, `.Inbox`, `.getMsg`, `.clearInbox`.
- **`local_api.lua`**: Provides `send` (for top-level messages), `eval`, `getFirstMsg/LastMsg`.
- **`local_scheduler.lua`**: Round-robin concurrency loop.
- **`ao.lua`**: The per-process AO runtime (storing outbox, references).
- **`local_eval_exp.lua`**: Evaluates Lua code strings for “EvalRequest.”
- **`assignment.lua`**: Extends `ao` with assignment logic.
- **`handlers.lua`**: Maintains a registry of message patterns → handler functions.
- **`serialize.lua`**: Recursively serializes and reconstructs table structures and bigints.
- **`default.lua`**: A default handler that logs unhandled messages.

This **local concurrency** environment allows **faster testing** of AO processes without the real decentralized protocol. Each process runs in isolation with a message queue, while `scheduler.run()` ensures they cooperatively consume messages.
