local process = {}

local log = require(".log")
local json = require(".json")
local createAO = require("aolite.factories.ao")
local createHandlers = require("aolite.factories.handlers")
local createProcess = require("aolite.factories.process")

local initialEnv = {} -- your old `initialEnv`, if you still need it
setmetatable(initialEnv, { __index = _G })

local function appendMsgLog(env, msg)
  local path = env.messageLogPath
  if not path then
    return
  end
  local file, err = io.open(path, "a")
  if not file then
    log.warn("aolite: Unable to open message log file: " .. tostring(err))
    return
  end
  local ok, encoded = pcall(json.encode, log.serializeData(msg))
  if ok then
    file:write(encoded .. "\n")
  else
    log.warn("aolite: Failed to encode message for logging: " .. tostring(encoded))
  end
  file:close()
end

local function findTag(tags, tname)
  if not tags then
    return nil
  end
  if tags then
    for _, t in ipairs(tags) do
      if t.name == tname then
        return t.value
      end
    end
  end
end

local function findObject(array, key, value)
  for _, object in ipairs(array) do
    if object[key] == value then
      return object
    end
  end
  return nil
end

local function setFrom(msg)
  if msg.From then
    return msg.From
  end

  local _from = findObject(msg.Tags, "name", "From-Process")
  if _from then
    return _from.value
  end
  return nil
end

local function ensureStandardMessageFields(msg, sourceId)
  msg.From = sourceId or setFrom(msg)
  msg.Owner = msg.Owner or msg.From
  msg.Timestamp = os.time()

  msg.Tags = msg.Tags or {}

  local _reference = findObject(msg.Tags, "name", "Reference")
  assert(_reference, "aolite: Reference tag is missing")

  msg.Id = msg.From .. ":" .. _reference.value

  -- Propagate Module tag to root field for upstream compatibility
  if not msg.Module then
    local _moduleTag = findObject(msg.Tags, "name", "Module")
    if _moduleTag then
      msg.Module = _moduleTag.value
    end
  end

  if msg["Block-Height"] == nil then
    local _bhTag = findObject(msg.Tags, "name", "Block-Height")
    if _bhTag then
      msg["Block-Height"] = tonumber(_bhTag.value) or _bhTag.value
    else
      msg["Block-Height"] = 0 -- fallback for tests, TODO: simulate?
    end
  end
end

local function addMsgToQueue(env, msg)
  if not msg.Target then
    error("aolite: Target process is nil")
  end
  if not env.queues or not env.queues[msg.Target] then
    error("aolite: Target process not found: " .. tostring(msg.Target))
  end

  if env.messageStore[msg.Id] then
    -- TODO: Find why some messages already exist in the store
    -- log.debug("aolite: Message for " .. msg.Target .. " already exists in store: " .. msg.Id .. " (skipped)")
  else
    -- log.debug("AddMsgToQueue of " .. msg.Target .. ":", msg)
    env.messageStore[msg.Id] = msg
    table.insert(env.queues[msg.Target], msg.Id)
  end

  env.ready[msg.Target] = true
end

function process.send(env, msg, fromId)
  ensureStandardMessageFields(msg, fromId)
  log.debug(
    "[message]: "
      .. fromId
      .. " -> "
      .. msg.Target
      .. " (Action = "
      .. (findTag(msg.Tags, "Action") or "?")
      .. ") "
      .. msg.Id
  )
  addMsgToQueue(env, msg)
  appendMsgLog(env, msg)
end

-- A helper to move outbox items to the correct inbound queues
function process.deliverOutbox(env, fromId, pushedFor)
  local proc = env.processes[fromId]
  assert(proc, "aolite: Process not found: " .. tostring(fromId))
  local ao = proc.ao
  local outbox = ao.outbox

  for _, msg in ipairs(outbox.Messages) do
    if not ao.isAssignment(msg) then
      msg["Pushed-For"] = msg["Pushed-For"] or pushedFor
    end
    process.send(env, msg, fromId)
  end

  for _, spawnMsg in ipairs(outbox.Spawns) do
    ensureStandardMessageFields(spawnMsg)
    local spawnedProc = process.spawnProcess(env, spawnMsg.Id, spawnMsg.Data, spawnMsg.Tags)
    spawnMsg.Action = "Spawned"
    spawnMsg.Target = spawnMsg.From
    spawnMsg.Process = spawnedProc.env.Process.Id

    addMsgToQueue(env, spawnMsg)
  end

  for _, assignment in ipairs(outbox.Assignments) do
    if not assignment.Message or not assignment.Processes then
      log.warn("aolite: Invalid assignment structure; missing fields")
    else
      local refMsg = env.messageStore[assignment.Message]
      if refMsg then
        for _, pid in ipairs(assignment.Processes) do
          if env.queues[pid] then
            table.insert(env.queues[pid], refMsg.Id)
            env.ready[pid] = true
          else
            error("aolite: Target process not found: " .. tostring(pid))
          end
        end
      end
    end
  end

  ao.clearOutbox()
end

function process.spawnProcess(env, originalId, dataOrPath, initEnv)
  assert(originalId, "parentId must be defined")
  if env.processes[originalId] then
    error("aolite: Process with ID " .. originalId .. " already exists")
  end
  log.debug("> LOG: Spawning process with ID: " .. originalId)

  -- local refVal = findTag(tags, "Reference")
  local processId = originalId
  local moduleId = findTag(initEnv, "Module") or "DefaultDummyModule"

  -- Create new Handlers & AO
  log.debug("> LOG: Creating handlers for: " .. processId .. " with module: " .. moduleId)
  local handlers = createHandlers(processId)
  local ao = createAO(handlers)
  local processModule = createProcess(ao, handlers)

  ao.authorities = { "DummyAuthority" }
  ao.id = processId
  ao._module = moduleId

  local processEnv = {
    Process = {
      Id = processId,
      Owner = "fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY",
      Tags = initEnv or {},
    },
    Handlers = handlers,
    ao = ao,
    Module = { Id = moduleId },
    -- Ensure each sandbox starts with its own isolated Inbox so that look-ups
    -- never fall back to the host _G.Inbox table via the metatable chain.
    Inbox = {},
    -- plus any other environment fields
  }
  -- Provide Receive() helper like upstream so user code can call it directly
  processEnv.Receive = function(match)
    return handlers.receive(match)
  end
  setmetatable(processEnv, { __index = initialEnv })

  -- Promote initEnv to globals
  if initEnv then
    for k, v in pairs(initEnv) do
      processEnv[k] = v
    end
  end
  processEnv._G = processEnv
  processEnv._ENV = processEnv

  -- keep pointer to outer simulator environment for factories
  processEnv._parent = env

  -- If upstream placed a global Receive function in the sandbox, prefer it.
  if type(processModule.Receive) == "function" then
    processEnv.Receive = processModule.Receive
  end

  -- Create a local package table in processEnv
  processEnv.package = {
    loaded = {
      ["ao"] = ao,
      ["Handlers"] = handlers,
      ["process"] = processModule,
      -- Preload any other modules as needed
    },
    searchers = package.searchers,
    path = package.path,
    cpath = package.cpath,
    config = package.config,
  }

  processEnv.require = function(moduleName)
    local loaded = processEnv.package.loaded
    if loaded[moduleName] then
      return loaded[moduleName]
    end

    local success, result = pcall(require, moduleName, processEnv)
    local firstError
    if success then
      loaded[moduleName] = result
      return result
    else
      -- If this attempt fails, 'result' should hold an error message
      firstError = result
    end

    local success2, result2 = pcall(require, moduleName)
    if success2 then
      loaded[moduleName] = result2
      return loaded[moduleName]
    else
      -- Print both errors for better visibility
      log.warn(
        "aolite: Failed to load module: "
          .. moduleName
          .. "\nFirst attempt error: "
          .. tostring(firstError)
          .. "\nSecond attempt error: "
          .. tostring(result2)
      )
    end
  end

  -- Save the process instance
  env.processes[processId] = {
    process = processModule,
    ao = ao,
    Handlers = handlers,
    env = processEnv,
  }

  -- Create inbound queue if not exist
  env.queues[processId] = env.queues[processId] or {}

  -- The process's main coroutine
  local function processLoop()
    local msg

    while true do
      process.deliverOutbox(env, processId, msg and msg.Id or nil)

      if #env.queues[processId] == 0 then
        --- log.debug("Finished looping")
        coroutine.yield()
      else
        -- pop one message
        local msgId = table.remove(env.queues[processId], 1)
        msg = env.messageStore[msgId]

        if not ao.isAssignment(msg) and env.processed[msg.Id] then
          error("aolite: Message already processed: " .. msg.Id)
        end
        processModule.handle(msg, processEnv)
        env.processed[msg.Id] = true
      end
    end
  end

  env.coroutines[processId] = coroutine.create(processLoop)

  -- Load and execute the process script in the processEnv
  local onBoot = findTag(initEnv, "On-Boot") or dataOrPath
  if onBoot then
    if onBoot == "Data" then
      local chunk, err = load(dataOrPath, "onboot", "bt", processEnv)
      if not chunk then
        error(err)
      end
      chunk()
    elseif onBoot ~= "NODATA" then
      processEnv.require(onBoot)
    end
  end
  processEnv.require("aolite.eval")

  -- Ensure AO table knows its environment before any messages arrive
  ao.env = processEnv

  return env.processes[processId]
end

return process
