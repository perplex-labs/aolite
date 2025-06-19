-- Factory that creates an isolated copy of the Process module per AO process
-- It executes the upstream implementation inside a fresh environment
-- so globals such as Inbox, Handler coroutines, etc. stay sandbox-local.
local compat_require = require -- after aolite.compat this is the dualRequire
local log = require(".log")

-- helper to shallow-clone a table (used to seed env.package.loaded)
local function clone(tbl)
  local t = {}
  for k, v in pairs(tbl) do
    t[k] = v
  end
  return t
end

return function(ao, Handlers)
  assert(type(ao) == "table" and type(Handlers) == "table", "ao and Handlers required")

  -- fresh environment that inherits from _G but shadows its own globals
  local env = { ao = ao, Handlers = Handlers }
  env._G = env -- make self-contained
  env._ENV = env

  -- prepare per-env package table so that `require` inside the sandbox reuses
  -- our already-built instances rather than loading new ones.
  env.package = {
    loaded = {
      ["ao"] = ao,
      [".ao"] = ao,
      ["Handlers"] = Handlers,
      [".handlers"] = Handlers,
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

  setmetatable(env, { __index = _G })

  -- Execute upstream process code inside this env and return its table
  local process = compat_require("aos.process.process", env)

  -- ------------------------------------------------------------------
  -- Back-compat helpers expected by aolite's public API
  -- ------------------------------------------------------------------
  if not process.getMsgs then
    -- filter over env.Inbox we maintain
    local function getMsgs(matchSpec, fromFirst, count)
      local utils = env.require(".utils")
      -- Use the Inbox maintained in the sandbox environment (set by ao.init)
      -- rather than the factory-local shadow.  This guarantees we see the
      -- same messages that the process itself sees when handling events.
      local src = env.Inbox or {}
      local results = {}
      fromFirst = fromFirst or false
      local maxCount = (count and count > 0) and count or nil

      local function maybeAdd(m)
        if not matchSpec or utils.matchesSpec(m, matchSpec) then
          table.insert(results, m)
          if maxCount and #results >= maxCount then
            return true
          end
        end
      end

      if fromFirst then
        for i = 1, #src do
          if maybeAdd(src[i]) then
            break
          end
        end
      else
        for i = #src, 1, -1 do
          if maybeAdd(src[i]) then
            break
          end
        end
      end
      return results
    end
    process.getMsgs = getMsgs
  end

  if not process.clearInbox then
    process.clearInbox = function()
      local cleared = #(env.Inbox or {})
      local newBox = {}
      env.Inbox = newBox
      if ao.env then
        ao.env.Inbox = newBox
      end
      return cleared
    end
  end

  -- ------------------------------------------------------------------
  -- Ensure every message seen by process.handle has a Module field so
  -- upstream RNG seeding never fails.
  -- ------------------------------------------------------------------
  do
    local origHandle = process.handle
    if type(origHandle) == "function" then
      process.handle = function(msg, _)
        -- ensure Module field
        if msg.Module == nil then
          -- 1) try root of ao table
          msg.Module = ao._module or msg.Module
          -- 2) fallback: look for Module tag and promote
          if msg.Module == nil and msg.Tags then
            for _, t in ipairs(msg.Tags) do
              if t.name == "Module" then
                msg.Module = t.value
                break
              end
            end
          end
        end

        -- Ensure env.Inbox exists and store current message for later queries
        local envRef = _.Process and _ or (_.env or _)
        if envRef then
          envRef.Inbox = envRef.Inbox or {}
          table.insert(envRef.Inbox, msg)
          local parent = envRef._parent
          if parent and parent.messageStore and msg.Id then
            parent.messageStore[msg.Id] = msg
          end
        end
        local res = { origHandle(msg, _) }

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
          for _, a in ipairs(ao.outbox.Assignments) do
            parent.messageStore[a.Message or a.Id or tostring(a)] = a
          end
        end

        -- Duplicate *only self-addressed* outbox messages into the sandbox
        -- inbox. This prevents other outbound traffic from polluting the
        -- caller's history and avoids duplicate entries when the same
        -- message is already present.
        if envRef then
          envRef.Inbox = envRef.Inbox or {}
          -- Ensure both the sandbox (_ENV) and the outer processEnv share
          -- the very same Inbox table so there is only ONE authoritative
          -- copy.
          if env.Inbox ~= envRef.Inbox then
            env.Inbox = envRef.Inbox
          end

          -- Build a quick set of already-present message IDs to de-duplicate.
          local seen = {}
          for _, existing in ipairs(envRef.Inbox) do
            if existing.Id then
              seen[existing.Id] = true
            end
          end

          local myId = envRef.Process and envRef.Process.Id

          local function maybeCopy(arr)
            for _, m in ipairs(arr) do
              if m.Target == myId and m.Id and not seen[m.Id] then
                table.insert(envRef.Inbox, m)
                seen[m.Id] = true
              end
            end
          end

          maybeCopy(ao.outbox.Messages)
          -- Spawn / Assignment records do not target this process directly,
          -- so we deliberately skip them here.
        end

        return table.unpack(res)
      end
    end
  end

  return process
end
