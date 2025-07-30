-- Factory that creates an isolated copy of the Process module per AO process
-- It executes the upstream implementation inside a fresh environment
-- so globals such as Inbox, Handler coroutines, etc. stay sandbox-local.
local compat_require = require -- after aolite.compat this is the dualRequire
local createAO = require("aolite.factories.ao")
local createHandlers = require("aolite.factories.handlers")

return function(processId, moduleId)
  -- Create new Handlers & AO
  local handlers = createHandlers(processId)
  local ao = createAO(processId, moduleId, handlers)

  -- fresh environment that inherits from _G but shadows its own globals
  local env = { ao = ao, Handlers = handlers }

  -- Create a private copy of every global so that mutations made by the
  -- process stay inside its sandbox.  We clone each global table once so
  -- that statements such as `os.time = ...` affect only this copy.
  local function __aolite_shallow_copy(t)
    local c = {}
    for k, v in pairs(t) do
      c[k] = v
    end
    return c
  end

  for k, v in pairs(_G) do
    if k ~= "_G" and k ~= "_ENV" and env[k] == nil then
      if type(v) == "table" then
        env[k] = __aolite_shallow_copy(v)
      else
        env[k] = v
      end
    end
  end
  env._G = env -- make self-contained
  env._ENV = env

  -- prepare per-env package table so that `require` inside the sandbox reuses
  -- our already-built instances rather than loading new ones.
  env.package = {
    loaded = {
      ["ao"] = ao,
      [".ao"] = ao,
      ["Handlers"] = handlers,
      [".handlers"] = handlers,
    },
  }

  -- sandbox-local require: first look in env.package.loaded, else delegate to
  -- compat dualRequire passing this env so nested loads also run inside.
  env.require = function(mod)
    local loaded = env.package.loaded
    if loaded[mod] then
      return loaded[mod]
    end

    -- Try compat dual require first
    local ok, res = pcall(compat_require, mod, env)
    if ok then
      loaded[mod] = res
      return res
    end

    -- If compat failed, fall back to plain global require with *original* name
    local ok2, res2 = pcall(require, mod)
    if ok2 then
      loaded[mod] = res2
      return res2
    end

    -- Last resort: if compat mapped the name (e.g. bit -> bit32), try that too
    local mapped = res -- res contains compat error string; but we need mapping
    -- However we can compute with resolveModulePath
    local mappedName = (type(mod) == "string" and type(resolveModulePath) == "function") and resolveModulePath(mod)
      or nil
    if mappedName and mappedName ~= mod then
      local ok3, res3 = pcall(require, mappedName)
      if ok3 then
        loaded[mod] = res3
        return res3
      end
    end

    error(res)
  end

  setmetatable(env, {
    __index = function()
      return nil
    end,
  })

  ---------------------------------------------------------------------------
  -- 2. Load the process implementation ------------------------------------
  -- If the caller provided a specific `moduleId` attempt to resolve it
  -- *inside the sandbox* first.  This allows users to provide their own Lua
  -- modules simply by publishing them on the regular Lua `package.path`.
  -- If the load fails for any reason (not found, syntax error, etc.) we
  -- gracefully fall back to the reference implementation so that the
  -- simulator keeps working.
  ---------------------------------------------------------------------------
  local process
  do
    local function tryRequire(mod)
      local ok, res = pcall(compat_require, mod, env)
      if ok then
        return res
      end
    end

    if moduleId and moduleId ~= "" and moduleId ~= "DefaultDummyModule" then
      -- Attempt to require the module from the file system first.
      process = tryRequire(moduleId)
    end

    -- Fallback to the built-in reference implementation when the custom
    -- module could not be loaded or returned nil / non-table.
    if not process or type(process) ~= "table" then
      process = compat_require("aos.process.process", env)
    end
  end

  -- Expose the sandbox so the caller can reuse it
  process._env = env

  -- ------------------------------------------------------------------
  -- Back-compat helpers expected by aolite's public API
  -- ------------------------------------------------------------------
  if not process.getMsgs then
    -- filter over env.Inbox we maintain
    local function getMsgs(matchSpec, fromFirst, count)
      local utils = env.require(".utils")
      -- Use the per-process arrival history that aolite maintains.
      -- History gives us message IDs in chronological order, each exactly once.
      local parent = env._parent
      local historyIds = (parent and parent.history and parent.history[processId]) or {}
      local results = {}
      fromFirst = fromFirst or false
      local maxCount = (count and count > 0) and count or nil

      local function maybeAdd(m)
        if m and (not matchSpec or utils.matchesSpec(m, matchSpec)) then
          table.insert(results, m)
          if maxCount and #results >= maxCount then
            return true
          end
        end
      end

      if fromFirst then
        for i = 1, #historyIds do
          local m = parent and parent.messageStore[historyIds[i]]
          if m and maybeAdd(m) then
            break
          end
        end
      else
        for i = #historyIds, 1, -1 do
          local m = parent and parent.messageStore[historyIds[i]]
          if m and maybeAdd(m) then
            break
          end
        end
      end
      return results
    end
    process.getMsgs = getMsgs
  end

  -- ------------------------------------------------------------------
  -- Ensure every message seen by process.handle has a Module field so
  -- upstream RNG seeding never fails.
  -- ------------------------------------------------------------------
  do
    local origHandle = process.handle
    if type(origHandle) == "function" then
      process.handle = function(msg, _)
        -- Ensure env.Inbox exists and store current message for later queries
        local envRef = _.Process and _ or (_.env or _)
        if envRef then
          envRef.Inbox = envRef.Inbox or {}
          local parent = envRef._parent
          if parent and parent.messageStore and msg.Id then
            parent.messageStore[msg.Id] = msg
          end
        end
        local res = { origHandle(msg, _) }

        ----------------------------------------------------------------
        -- If the custom module returned an outbox *value* instead of
        -- populating ao.outbox directly (the canonical pattern for the
        -- reference module), adopt that here so the simulator can continue
        -- using its regular delivery pipeline.
        ----------------------------------------------------------------
        if (#ao.outbox.Messages == 0) and (type(res[1]) == "table") then
          local candidate = res[1]
          if candidate.Messages or candidate.Spawns or candidate.Assignments or candidate.Output or candidate.Error then
            ao.outbox = {
              Messages = candidate.Messages or {},
              Spawns = candidate.Spawns or {},
              Assignments = candidate.Assignments or {},
              Output = candidate.Output or {},
              Error = candidate.Error,
            }
          end
        end

        -- After handler: copy any newly queued outbox items to global store
        local parent = envRef and envRef._parent
        if parent and parent.messageStore then
          for _, m in ipairs(ao.outbox.Messages) do
            if m.Id then
              parent.messageStore[m.Id] = m
            end
          end
          for _, s in ipairs(ao.outbox.Spawns) do
            if s.Id then
              parent.messageStore[s.Id] = s
            end
          end
        end

        return table.unpack(res)
      end
    end
  end

  return process
end
