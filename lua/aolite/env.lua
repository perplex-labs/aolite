local LocalAOEnv = {}

function LocalAOEnv.new()
  local self = {
    processes = {}, -- [processId] = { process, ao, Handlers, env }
    coroutines = {}, -- [processId] = coroutine
    queues = {}, -- inbound queues: [processId] = { msg1, msg2, ... }
    processed = {},
    messageStore = {}, -- all processed messages by ID
    ready = {}, -- set of processIds that have messages (and need scheduling)
    autoSchedule = true,
    messageLogPath = os.getenv("AOLITE_MSG_LOG"),
    printProcessOutput = (os.getenv("AOLITE_PRINT_OUTPUT") or "") ~= "" and os.getenv("AOLITE_PRINT_OUTPUT") ~= "0",
  }
  return self
end

return LocalAOEnv
