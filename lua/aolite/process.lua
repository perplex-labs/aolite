local process = {}

local log = require(".log")
local json = require(".json")
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

local function flushProcessOutput(env, processId, runtimeEnv)
  if not env.printProcessOutput then
    return
  end
  local out = runtimeEnv.ao and runtimeEnv.ao.outbox and runtimeEnv.ao.outbox.Output
  if out and out.data and out.data ~= "" then
    log.debug("[" .. processId .. "] " .. tostring(out.data))
  end
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

local function ensureStandardMessageFields(env, msg, sourceId)
  msg.From = sourceId or setFrom(msg)
  msg.Owner = msg.Owner or msg.From
  msg.Timestamp = os.time()

  msg.Tags = msg.Tags or {}

  local _reference = findObject(msg.Tags, "name", "Reference")
  assert(_reference, "aolite: Reference tag is missing")

  msg.Id = msg.From .. "#" .. _reference.value

  if msg["Block-Height"] == nil then
    local _bhTag = findObject(msg.Tags, "name", "Block-Height")
    if _bhTag then
      msg["Block-Height"] = tonumber(_bhTag.value) or _bhTag.value
    else
      msg["Block-Height"] = 0 -- fallback for tests, TODO: simulate?
    end
  end

  -- ensure Module field and From-Module tag
  if not msg.Module then
    -- Derive the module id from the process that is sending the message
    local sender = msg.From and env.processes and env.processes[msg.From]
    msg.Module = sender.ao._module
    if not findObject(msg.Tags, "name", "From-Module") then
      table.insert(msg.Tags, { name = "From-Module", value = msg.Module })
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

    local action = findTag(msg.Tags, "Action")
    if action ~= "EvalRequest" and action ~= "EvalResponse" then
      log.debug(
        "[\27[34maolite\27[0m] message "
          .. msg.From
          .. " -> "
          .. msg.Target
          .. " (Action = "
          .. (action or "nil")
          .. ", Id = "
          .. msg.Id
          .. ")"
      )
    end
  end

  env.ready[msg.Target] = true
end

function process.send(env, msg, fromId)
  ensureStandardMessageFields(env, msg, fromId)
  addMsgToQueue(env, msg)
  appendMsgLog(env, msg)
end

-- Helper allocating the next child-process id for a given parent process
local function nextChildProcessId(env, parentId)
  local parent = env.processes[parentId]
  assert(parent, "aolite: Parent process not found: " .. tostring(parentId))
  parent.spawnCounter = (parent.spawnCounter or 0) + 1
  return parentId .. ":" .. tostring(parent.spawnCounter)
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
    ensureStandardMessageFields(env, spawnMsg)

    -- Allocate a hierarchical id for the new child using the parent-specific
    -- spawn counter (separate from the parent's message reference counter)
    local childProcessId = nextChildProcessId(env, fromId)

    local spawnedProc = process.spawnProcess(env, childProcessId, spawnMsg.Data, spawnMsg.Tags, fromId)

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

function process.spawnProcess(env, processId, dataOrPath, initEnv, ownerId)
  assert(processId, "processId must be defined")

  -- Normalize `initEnv`.
  -- It can be:
  --   1. A map:  { key = value, ... }
  --   2. An array: { { name = key, value = value }, ... }
  local tagMap, tagList = {}, {}

  if initEnv ~= nil then
    assert(type(initEnv) == "table", "`initEnv` must be a table")

    local isArray = initEnv[1] ~= nil and type(initEnv[1]) == "table" and initEnv[1].name ~= nil

    if isArray then
      for _, tag in ipairs(initEnv) do
        assert(type(tag.name) == "string", "Each tag item needs a string `name` field")
        tagMap[tag.name] = tag.value
        table.insert(tagList, { name = tag.name, value = tag.value })
      end
    else
      for key, value in pairs(initEnv) do
        assert(type(key) == "string", "`initEnv` map keys must be strings")
        tagMap[key] = value
        table.insert(tagList, { name = key, value = value })
      end
    end
  end

  if env.processes[processId] then
    error("aolite: Process with ID " .. processId .. " already exists")
  end
  local moduleId = tagMap.Module or "DefaultDummyModule"
  log.debug("[\27[34maolite\27[0m] spawning process id: " .. processId .. " & module: " .. moduleId)

  local processModule = createProcess(processId, moduleId)

  -- AFTER you obtained processModule from createProcess(...)
  local runtimeEnv = assert(processModule._env, "process sandbox missing")

  -- augment it with runtime-specific fields that the simulator expects
  runtimeEnv.Process = {
    Id = processId,
    Owner = ownerId or processId,
    Tags = tagList,
  }
  -- TODO: This is a workaround for the currently missing initial
  --       spawn message which normally sets the Owner and Name fields of a process.
  runtimeEnv.Owner = ownerId or processId
  runtimeEnv.Name = processId

  -- Promote initEnv tags to globals so blue-print code can access them
  if initEnv then
    for key, value in pairs(tagMap) do
      runtimeEnv[key] = value
    end
  end

  runtimeEnv.Inbox = {} -- isolated inbox for this process
  runtimeEnv._parent = env -- pointer back to simulator host

  -- Provide a convenience Receive() helper *only* if the sandbox exposes
  -- Handlers with a `receive` method and if the module hasn't defined its
  -- own Receive already.
  if runtimeEnv.Receive == nil then
    local hs = runtimeEnv.Handlers
    if type(hs) == "table" and type(hs.receive) == "function" then
      runtimeEnv.Receive = function(match)
        return hs.receive(match)
      end
    end
  end

  -- Allow the module itself to override the helper with its own
  if type(processModule.Receive) == "function" then
    runtimeEnv.Receive = processModule.Receive
  end

  ------------------------------------------------------------------
  -- Persist references so the simulator can access them later      --
  ------------------------------------------------------------------
  local ao = runtimeEnv.ao -- same table the sandbox uses
  local handlers = runtimeEnv.Handlers

  -- From here on, treat 'runtimeEnv' as the authoritative sandbox
  ao.env = runtimeEnv
  env.processes[processId] = {
    process = processModule,
    ao = ao,
    Handlers = handlers,
    env = runtimeEnv, --  <──  store the *same* table
    -- initialise dedicated spawn counter for this process
    spawnCounter = 0,
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
        if runtimeEnv.Process.Tags[1] == nil then -- not an array any more
          local arr = {}
          for k, v in pairs(runtimeEnv.Process.Tags) do
            table.insert(arr, { name = k, value = v })
          end
          runtimeEnv.Process.Tags = arr
        end
        processModule.handle(msg, runtimeEnv)
        flushProcessOutput(env, processId, runtimeEnv)
        env.processed[msg.Id] = true
      end
    end
  end

  env.coroutines[processId] = coroutine.create(processLoop)

  -- Load and execute the process script in the processEnv
  local onBoot = initEnv and tagMap["On-Boot"] or dataOrPath
  if onBoot then
    if onBoot == "Data" then
      local chunk, err = load(dataOrPath, "onboot", "bt", runtimeEnv)
      if not chunk then
        error(err)
      end
      chunk()
    elseif onBoot ~= "NODATA" then
      runtimeEnv.require(onBoot)
    end
  end
  runtimeEnv.require("aolite.eval")

  -- Print any on-boot prints if printProcessOutput is enabled
  flushProcessOutput(env, processId, runtimeEnv)

  -- Ensure AO table knows its environment before any messages arrive
  ao.env = runtimeEnv

  return env.processes[processId]
end

return process
