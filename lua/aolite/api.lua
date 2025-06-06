local api = {}
local json = require("aolite.lib.json")
local serialize = require("aolite.lib.serialize")
local scheduler = require("aolite.scheduler")
local process = require("aolite.process")

function api.send(env, msg, clearInbox)
  assert(type(msg.From) == "string", "From must be defined")
  assert(type(msg.Target) == "string", "Target must be defined")

  local fromProc = env.processes[msg.From]
  if not fromProc then
    error("aolite: No such process: " .. tostring(msg.From))
  end
  if clearInbox then
    fromProc.process.clearInbox()
  end

  local queuedMsg = fromProc.ao.send(msg)
  process.send(env, queuedMsg, msg.From)

  return queuedMsg
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

function api.getMsg(env, messageId)
  return env.messageStore[messageId]
end

function api.eval(env, processId, expression)
  assert(type(processId) == "string", "processId must be defined")
  api.send(env, {
    From = processId,
    Target = processId,
    Action = "EvalRequest",
    Expression = expression,
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
