local _utils = { _version = "0.0.1" }

local utils = require(".utils")
local ao = require(".ao") -- TODO: Fix?

function _utils.matchesSpec(msg, spec)
  if type(spec) == "function" then
    return spec(msg)
    -- If the spec is a table, step through every key/value pair in the pattern and check if the msg matches
    -- Supported pattern types:
    --   - Exact string match
    --   - Lua gmatch string
    --   - '_' (wildcard: Message has tag, but can be any value)
    --   - Function execution on the tag, optionally using the msg as the second argument
    --   - Table of patterns, where ANY of the sub-patterns matching the tag will result in a match
  end
  if type(spec) == "table" then
    for key, pattern in pairs(spec) do
      if not msg[key] then
        return false
      end
      if not utils.matchesPattern(pattern, msg[key], msg) then
        return false
      end
    end
    return true
  end
  if type(spec) == "string" and msg.Action and msg.Action == spec then
    return true
  end
  return false
end

function _utils.hasMatchingTag(name, value)
  assert(type(name) == "string" and type(value) == "string", "invalid arguments: (name : string, value : string)")

  return function(msg)
    return msg.Tags[name] == value
  end
end

function _utils.hasMatchingTagOf(name, values)
  assert(type(name) == "string" and type(values) == "table", "invalid arguments: (name : string, values : string[])")
  return function(msg)
    for _, value in ipairs(values) do
      local patternResult = Handlers.utils.hasMatchingTag(name, value)(msg)

      if patternResult ~= 0 and patternResult ~= false and patternResult ~= "skip" then
        return patternResult
      end
    end

    return 0
  end
end

function _utils.hasMatchingData(value)
  assert(type(value) == "string", "invalid arguments: (value : string)")
  return function(msg)
    return msg.Data == value
  end
end

function _utils.reply(input)
  assert(type(input) == "table" or type(input) == "string", "invalid arguments: (input : table or string)")
  return function(msg)
    if type(input) == "string" then
      ao.send({ Target = msg.From, Data = input })
      return
    end
    ao.send({ Target = msg.From, Tags = input })
  end
end

function _utils.continue(fn)
  assert(type(fn) == "function", "invalid arguments: (fn : function)")
  return function(msg)
    local patternResult = fn(msg)

    if not patternResult or patternResult == 0 or patternResult == "skip" then
      return patternResult
    end
    return 1
  end
end

return _utils
