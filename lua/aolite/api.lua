local api = {}
local json = require("json")
local serialize = require(".serialize")
local scheduler = require("aolite.scheduler")
local process = require("aolite.process")

function api.send(env, msg)
  assert(type(msg.From) == "string", "From must be defined")
  assert(type(msg.Target) == "string", "Target must be defined")

  local fromProc = env.processes[msg.From]
  if not fromProc then
    error("aolite: No such process: " .. tostring(msg.From))
  end

  local queuedMsg = fromProc.ao.send(msg)
  process.send(env, queuedMsg, msg.From)

  return queuedMsg
end

-- Clear all recorded messages for a given process (history + sandbox inbox).
function api.clearAllMessages(env, processId)
  if not processId then
    error("processId must be provided")
  end

  -- Reset history bucket
  env.history = env.history or {}
  env.history[processId] = {}

  -- Note: We deliberately leave env.messageStore untouched so that other
  -- processes referencing older messages keep working.

  return true
end

function api.getFirstMsg(env, processId, matchSpec)
  if env.autoSchedule then
    scheduler.run(env)
  end
  local proc = env.processes[processId]
  if not proc then
    return nil
  end
  return proc.process.getMsgs(matchSpec, true, 1)[1]
end

function api.getLastMsg(env, processId, matchSpec)
  if env.autoSchedule then
    scheduler.run(env)
  end
  local proc = env.processes[processId]
  if not proc then
    return nil
  end
  return proc.process.getMsgs(matchSpec, false, 1)[1]
end

function api.getAllMsgs(env, processId, matchSpec)
  if env.autoSchedule then
    scheduler.run(env)
  end
  local proc = env.processes[processId]
  if not proc then
    return nil
  end
  return proc.process.getMsgs(matchSpec, false)
end

function api.getMsgById(env, messageId)
  return env.messageStore[messageId]
end

function api.getMsgs(env, matchSpec)
  local utils = require(".utils")
  local results = {}
  for _, msg in pairs(env.messageStore) do
    if utils.matchesSpec(msg, matchSpec) then
      table.insert(results, msg)
    end
  end
  return results
end

function api.eval(env, processId, expression)
  assert(type(processId) == "string", "processId must be defined")
  -- EvalRequest expects the code in the Data field so that it survives
  -- ao.send (which only preserves Target and Data in the root table).
  api.send(env, {
    From = processId,
    Target = processId,
    Action = "EvalRequest",
    Data = expression,
  })

  local matchSpec = { From = processId, Action = "EvalResponse" }
  local resp = api.getLastMsg(env, processId, matchSpec)

  if resp and resp.Error then
    error("Error in evaluation: " .. resp.Error)
  end
  -- 3) If success, decode resp.Data
  if resp and resp.Data then
    local data = json.decode(resp.Data)
    return serialize.reconstruct(data)
  end
  return nil
end

return api
