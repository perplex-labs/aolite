require("aolite.compat")()
local LocalEnv = require("aolite.env")
local process = require("aolite.process")
local api = require("aolite.api")
local scheduler = require("aolite.scheduler")

local M = {}
-- Create a "singleton" environment for tests
local env = LocalEnv.new()

function M.spawnProcess(originalId, dataOrPath, tags)
  return process.spawnProcess(env, originalId, dataOrPath, tags)
end

function M.send(msg)
  local queuedMsg = api.send(env, msg)

  if env.autoSchedule then
    scheduler.run(env)
  end

  return queuedMsg
end

-- Clear per-process message history (Inbox + aolite history bucket)
function M.clearAllMessages(processId)
  return api.clearAllMessages(env, processId)
end

function M.getFirstMsg(processId, matchSpec)
  return api.getFirstMsg(env, processId, matchSpec)
end

function M.getLastMsg(processId, matchSpec)
  return api.getLastMsg(env, processId, matchSpec)
end

function M.getAllMsgs(processId, matchSpec)
  return api.getAllMsgs(env, processId, matchSpec)
end

function M.getMsgById(messageId)
  return api.getMsgById(env, messageId)
end

function M.getMsgs(matchSpec)
  return api.getMsgs(env, matchSpec)
end

function M.eval(processId, expression)
  return api.eval(env, processId, expression)
end

function M.clearAllProcesses()
  -- Stop tracking all processes in env.processes
  for pid, proc in pairs(env.processes) do
    env.coroutines[pid] = nil
    env.queues[pid] = nil
    -- wipe per-sandbox inbox created during execution
    if proc.env then
      proc.env.Inbox = {}
    end
  end

  env.processes = {}
  env.messageStore = {}
  env.processed = {}
  env.ready = {}
  env.coroutines = {}
  env.history = {}
  -- defensive: clear any stray global fallback inbox
  _G.Inbox = {}
end

-- Concurrency: Scheduling & Reordering
function M.runScheduler(cycles)
  scheduler.run(env, cycles)
end

function M.isAutoSchedule()
  return env.autoSchedule == true
end

function M.setAutoSchedule(mode)
  if type(mode) ~= "boolean" then
    error("setAutoSchedule expects a boolean")
  end
  env.autoSchedule = mode
end

function M.setMessageLog(path)
  env.messageLogPath = path
end

function M.getMessageLog()
  return env.messageLogPath
end

function M.queue(msg)
  return api.queue(env, msg)
end

-- Inspect inbound queue (full messages)
function M.listQueueMessages(processId)
  local q = env.queues[processId]
  if not q then
    return nil
  end
  local result = {}
  for _, msgId in ipairs(q) do
    local msg = env.messageStore[msgId]
    table.insert(result, msg)
  end
  return result
end

-- Reorder the inbound queue with a custom array of msg IDs
function M.reorderQueue(processId, newOrderIds)
  local q = env.queues[processId]
  if not q then
    error("No queue found for processId: " .. tostring(processId))
  end
  if #q ~= #newOrderIds then
    error("newOrderIds must have exactly " .. #q .. " items")
  end
  -- (Optional) check if it's a permutation
  env.queues[processId] = {}
  for _, msgId in ipairs(newOrderIds) do
    table.insert(env.queues[processId], msgId)
  end
end

function M.setPrintProcessOutput(mode)
  if type(mode) ~= "boolean" then
    error("setPrintProcessOutput expects a boolean")
  end
  env.printProcessOutput = mode
end

function M.isPrintProcessOutput()
  return env.printProcessOutput == true
end

return M
