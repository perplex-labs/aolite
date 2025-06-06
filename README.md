# aolite

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A local, concurrent emulation of the Arweave AO protocol for testing Lua processes.

`aolite` provides a simulated Arweave AO environment for developers to test their AO processes and interactions locally. It includes support for message passing, process spawning, scheduling, and state serialization, all within a single Lua runtime.

## Features

- **Local AO Environment:** Spawn and test AO processes in-memory, leveraging all default AO module features.
- **Concurrent Process Emulation:** Uses coroutines to emulate concurrent execution of multiple processes.
- **Message Passing:** A simple API for sending messages between processes.
- **Process State Access:** Directly run Eval inside any process to access or modify its state.
- **Scheduler Control:** Supports both automatic and manual scheduling of process message queues.
- **Controlled Logging:** Supports logging at different levels of verbosity.

## Installation

You can install `aolite` using Luarocks:

```bash
luarocks install aolite
```

or build it from inside this repository directly:
```bash
luarocks make
```

## Quick Start

Here's a simple example of how to use `aolite` to test a process.

First, create a simple process file `process-source.lua` (or use your existing process source code file):
```lua
-- process-source.lua
print("Process loaded with ID: " .. ao.id)
Handlers.add("Ping", function(msg)
    msg.reply({ Action = "Pong" })
end)
```

Now, you can write a test script to spawn and interact with this process:
```lua
-- test.lua
local aolite = require("aolite")

-- Spawn the process with the source file
local processId = "Process1"
aolite.spawnProcess(processId, "process-source")

-- Send a message to the process to evaluate some Lua code
local msg = {
    From = processId,
    Target = processId,
    Action = "Ping",
}
aolite.send(msg)

-- Get the last message from the process
local response = aolite.getLastMsg(processId)
print("Response from process: " .. response.Action)

-- Expected output:
-- Process loaded with ID: Process1
-- Response from process: Pong
```

Run the test script:
```bash
lua test.lua
```

## Examples

Several small example scripts are available in the `examples` directory. Each of
them can be run directly with `lua` and showcases different aspects of the
library:

- `ping_pong.lua` – minimal Ping/Pong handler.
- `eval_example.lua` – evaluating code inside a running process.
- `scheduler_example.lua` – using the manual scheduler and message queues.

```bash
lua examples/ping_pong.lua
```

## API Overview

`aolite` provides a simple API to interact with the emulated environment.

- `aolite.spawnProcess(processId, dataOrPath, tags)`: Spawns a new process from source code or a file path.
- `aolite.send(msg)`: Sends a message to a process. The scheduler runs automatically by default.
- `aolite.getAllMsgs(processId)`: Returns all messages sent to a given process.
- `aolite.getLastMsg(processId)`: Returns only the last message sent to a given process.
- `aolite.getFirstMsg(processId)`: Returns only the first message sent to a given process.
- `aolite.eval(processId, expression)`: Evaluates a Lua expression within the context of a given process and returns the result.
- `aolite.setAutoSchedule(boolean)`: Enable or disable automatic scheduling after each `send`.
- `aolite.runScheduler()`: Manually trigger the scheduler to process message queues.
- `aolite.queue(msg)`: Manually queue a message without running the scheduler.
- `aolite.listQueueMessages(processId)`: Get the full list of messages in the queue for a specific process.
- `aolite.reorderQueue(processId, msgIds)`: Manually reorder the queue for a specific process.
- `aolite.clearAllProcesses()`: Clears all processes from the environment.

## Logging

`aolite` uses the `aolite.lib.log` module to log messages. The log level can be set by setting the `AOLITE_PRINT_VERB` environment variable where you run lua. The default log level is 0 (no logging).

The log level can be set to one of the following:

- `0` (no logging)
- `1` (warn)
- `2` (info)
- `3` (debug)

You can also set the log level in the test script:
```lua
PrintVerb = 3
```
and use the log module yourself:
```lua
local log = require("aolite.lib.log")
log.debug("This is a debug message")
```

If you wish to capture every message exchanged between processes, set the
`AOLITE_MSG_LOG` environment variable to a file path or configure it at runtime
using `aolite.setMessageLog`:

```lua
aolite.setMessageLog("./messages.log")
```

Each message queued by `aolite` will be serialized as JSON and appended to the
specified file. You can check the current log path with `aolite.getMessageLog()`.

## Usage

### Spawning Processes

There are two ways to load code when spawning a process:

1. From a string:
```lua
local sourceCodeString = [[
print("Hello, world!")
]]
aolite.spawnProcess(
  "process1",
  sourceCodeString,
  -- You must include the On-Boot tag to ensure the code is loaded.
  { { name = "On-Boot", value = "Data" } }
)
```

2. From a file:
```lua
aolite.spawnProcess(
  "process1",
  -- the .lua extension MUST be omitted
  "path.to.process-source",
)
```

### Eval

You can run Lua code inside any process by using the `aolite.eval` function.

```lua
local result = aolite.eval("process1", "return 1 + 2")
print(result) -- 3
```

You can use this to access or modify the state of any process just like you would with AOS.

### Sending Messages

```lua
aolite.send({
  -- You must include the From and Target fields with valid process IDs that you have already spawned.
  From = "process1",
  Target = "process2",
  Action = "Ping",
  Data = "Hello, world!",
  Tags = { Foo = "Bar" },
})
```

### Getting Messages

There are a few utility functions to help you access a specific process's inbox. Using any of these functions will automatically run the scheduler (unless you have disabled auto-scheduling).

```lua
-- Get all messages from the inbox
local msgs = aolite.getAllMsgs("process1")
print("Inbox:")
for i, msg in ipairs(msgs) do
  print("Inbox[" .. i .. "]: " .. msg.Action)
end
```

```lua
-- Get the last message from the inbox
local msg = aolite.getLastMsg("process1")
print("Last message: " .. msg.Action)
```

```lua
-- Get the first message from the inbox
local msg = aolite.getFirstMsg("process1")
print("First message: " .. msg.Action)
```

### Scheduling Messages

`aolite` supports both automatic and manual scheduling of process message queues (inbox).

By default, `aolite` will automatically run the scheduler right when you send a message. You can disable this by setting `aolite.setAutoSchedule(false)`.

You can manually run the scheduler by calling `aolite.runScheduler()`.
```lua
aolite.runScheduler()
```

You can also use the `aolite.queue` function to manually queue a message without running the scheduler.
```lua
aolite.queue(msg)
```
You can use the `aolite.listQueueMessages` function to get the full list of messages in the queue for a specific process.
```lua
local msgs = aolite.listQueueMessages("process1")
print("Queue:")
for i, msg in ipairs(msgs) do
  print("Queue[" .. i .. "]: " .. msg.Action)
end
```

You can use the `aolite.reorderQueue` function to manually reorder the queue for a specific process. This is useful if you want to prioritize certain messages or if you want to simulate a different order of messages.
```lua
aolite.reorderQueue("process1", { "msg-id-1", "msg-id-2", "msg-id-3" })
aolite.runScheduler()
```

### Cleaning Up

You can reset the environment by calling `aolite.clearAllProcesses()`.
```lua
aolite.clearAllProcesses()
```


## Development

There are no dependencies, simply modify the `lua/aolite` directory and run `luarocks make` to build the package. Luarocks will automatically install the package to your local lua path.

For running the test suite, this project uses [busted](https://lunarmodules.github.io/busted/). After installing it with `luarocks install busted`, simply run `make test`.
All pull requests are automatically tested using GitHub Actions.

Contributions are welcome! Feel free to open an issue or pull request.
