local function createHandlers(processId)
  local handlers = { _version = "0.0.3" }
  local coroutine = require("coroutine")
  local utils = require("aolite.lib.utils")
  local log = require("aolite.lib.log")
  handlers.utils = require("aolite.ao.handlers-utils")

  -- Initialize handler lists and coroutines
  handlers.list = handlers.list or {}
  handlers.coroutines = handlers.coroutines or {}
  handlers.onceNonce = 0

  -- Helper function to find the index of an object in an array by property
  local function findIndexByProp(array, prop, value)
    for index, object in ipairs(array) do
      if object[prop] == value then
        return index
      end
    end
    return nil
  end

  -- Helper function to assert the correctness of arguments when adding a handler
  local function assertAddArgs(name, pattern, handle, maxRuns)
    assert(
      type(name) == "string" and (type(pattern) == "function" or type(pattern) == "table" or type(pattern) == "string"),
      "Invalid arguments given. Expected: \n"
      .. "\tname : string, "
      .. "\tpattern : Action : string | MsgMatch : table,\n"
      .. "\t\tfunction(msg: Message) : {-1 = break, 0 = skip, 1 = continue},\n"
      .. "\thandle(msg : Message) : void) | Resolver,\n"
      .. '\tMaxRuns? : number | "inf" | nil'
    )
  end

  -- Function to generate a resolver based on the provided specification
  function handlers.generateResolver(resolveSpec)
    return function(msg)
      -- If the resolver is a single function, call it.
      -- Else, find the first matching pattern (by its matchSpec), and execute it.
      if type(resolveSpec) == "function" then
        return resolveSpec(msg)
      else
        for matchSpec, func in pairs(resolveSpec) do
          if utils.matchesSpec(msg, matchSpec) then
            return func(msg)
          end
        end
      end
    end
  end

  -- Function to add a new handler
  function handlers.add(...)
    handlers.list = handlers.list or {}
    local name, pattern, handle, maxRuns

    local args = select("#", ...)
    if args == 2 then
      name = select(1, ...)
      pattern = select(1, ...)
      handle = select(2, ...)
      maxRuns = nil
    elseif args == 3 then
      name = select(1, ...)
      pattern = select(2, ...)
      handle = select(3, ...)
      maxRuns = nil
    else
      name = select(1, ...)
      pattern = select(2, ...)
      handle = select(3, ...)
      maxRuns = select(4, ...)
    end
    assertAddArgs(name, pattern, handle, maxRuns)

    handle = handlers.generateResolver(handle)

    -- Update existing handler by name
    local idx = findIndexByProp(handlers.list, "name", name)
    if idx ~= nil and idx > 0 then
      -- Found existing handler; update it
      handlers.list[idx].pattern = pattern
      handlers.list[idx].handle = handle
      handlers.list[idx].maxRuns = maxRuns
    else
      -- Not found; add new handler
      table.insert(handlers.list, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
      log.debug("> LOG: Handler added for " .. tostring(processId) .. ": " .. name .. " " .. #handlers.list)
    end
    return #handlers.list
  end

  function handlers.append(...)
    local name, pattern, handle, maxRuns
    local args = select("#", ...)
    if args == 2 then
      name = select(1, ...)
      pattern = select(1, ...)
      handle = select(2, ...)
      maxRuns = nil
    elseif args == 3 then
      name = select(1, ...)
      pattern = select(2, ...)
      handle = select(3, ...)
      maxRuns = nil
    else
      name = select(1, ...)
      pattern = select(2, ...)
      handle = select(3, ...)
      maxRuns = select(4, ...)
    end
    assertAddArgs(name, pattern, handle, maxRuns)

    handle = handlers.generateResolver(handle)
    -- update existing handler by name
    local idx = findIndexByProp(handlers.list, "name", name)
    if idx ~= nil and idx > 0 then
      -- found update
      handlers.list[idx].pattern = pattern
      handlers.list[idx].handle = handle
      handlers.list[idx].maxRuns = maxRuns
    else
      table.insert(handlers.list, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
    end
  end

  --- Prepends a new handler to the beginning of the handlers list.
  -- @function prepend
  -- @tparam {string} name The name of the handler
  -- @tparam {table | function | string} pattern The pattern to check for in the message
  -- @tparam {function} handle The function to call if the pattern matches
  -- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
  function handlers.prepend(...)
    local name, pattern, handle, maxRuns
    local args = select("#", ...)
    if args == 2 then
      name = select(1, ...)
      pattern = select(1, ...)
      handle = select(2, ...)
      maxRuns = nil
    elseif args == 3 then
      name = select(1, ...)
      pattern = select(2, ...)
      handle = select(3, ...)
      maxRuns = nil
    else
      name = select(1, ...)
      pattern = select(2, ...)
      handle = select(3, ...)
      maxRuns = select(4, ...)
    end
    assertAddArgs(name, pattern, handle, maxRuns)

    handle = handlers.generateResolver(handle)

    -- update existing handler by name
    local idx = findIndexByProp(handlers.list, "name", name)
    if idx ~= nil and idx > 0 then
      -- found update
      handlers.list[idx].pattern = pattern
      handlers.list[idx].handle = handle
      handlers.list[idx].maxRuns = maxRuns
    else
      table.insert(handlers.list, 1, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
    end
  end

  -- Returns the next message that matches the pattern
  -- This function uses Lua's coroutines under-the-hood to add a handler, pause,
  -- and then resume the current coroutine. This allows us to effectively block
  -- processing of one message until another is received that matches the pattern.
  function handlers.receive(pattern)
    local self = coroutine.running()
    handlers.once(pattern, function(msg)
      -- If the result of the resumed coroutine is an error then we should bubble it up to the process
      local _, success, errmsg = coroutine.resume(self, msg)
      if not success then
        error(errmsg)
      end
    end)
    return coroutine.yield(pattern)
  end

  -- Function to add a handler that runs only once
  function handlers.once(...)
    local name, pattern, handle
    if select("#", ...) == 3 then
      name = select(1, ...)
      pattern = select(2, ...)
      handle = select(3, ...)
    else
      name = "_once_" .. tostring(handlers.onceNonce)
      handlers.onceNonce = handlers.onceNonce + 1
      pattern = select(1, ...)
      handle = select(2, ...)
    end
    handlers.prepend(name, pattern, handle, 1)
  end

  -- Function to remove a handler by name
  function handlers.remove(name)
    assert(type(name) == "string", "name MUST be string")

    -- If there's only one handler and its name matches, clear the list
    if #handlers.list == 1 and handlers.list[1].name == name then
      handlers.list = {}
      return
    end

    -- Find the index of the handler with the given name
    local idx = findIndexByProp(handlers.list, "name", name)
    if idx ~= nil and idx > 0 then
      table.remove(handlers.list, idx)
    end
  end

  -- Function to evaluate a message against all handlers
  -- Returns 0 to not call handler, -1 to break after handler is called, 1 to continue
  function handlers.evaluate(msg, env)
    local currentHandlers = handlers.list
    local handled = false
    assert(type(msg) == "table", "msg is not valid")
    assert(type(env) == "table", "env is not valid")

    for _, o in ipairs(currentHandlers) do
      if o.name ~= "_default" then
        local match = utils.matchesSpec(msg, o.pattern)
        if not (type(match) == "number" or type(match) == "string" or type(match) == "boolean") then
          error("Pattern result is not valid, it MUST be string, number, or boolean")
        end

        -- Handle boolean returns
        if type(match) == "boolean" then
          if match then
            match = -1
          else
            match = 0
          end
        end

        -- Handle string returns
        if type(match) == "string" then
          if match == "continue" then
            match = 1
          elseif match == "break" then
            match = -1
          else
            match = 0
          end
        end

        if match ~= 0 then
          if match < 0 then
            handled = true
          end
          -- Each handle function can accept the msg and env
          local status, err = pcall(o.handle, msg, env)
          if not status then
            error(err)
          end
          -- Remove handler if maxRuns is reached. maxRuns can be either a number or "inf"
          if o.maxRuns ~= nil and o.maxRuns ~= "inf" then
            o.maxRuns = o.maxRuns - 1
            if o.maxRuns == 0 then
              handlers.remove(o.name)
            end
          end
        end
        if match < 0 then
          return handled
        end
      end
    end

    -- Handle default handler if necessary (commented out)
    -- if not handled then
    --   local idx = findIndexByProp(handlers.list, "name", "_default")
    --   handlers.list[idx].handle(msg, env)
    -- end
  end

  return handlers
end

return createHandlers
