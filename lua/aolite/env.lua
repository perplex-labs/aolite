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
  }
  return self
end

return LocalAOEnv
