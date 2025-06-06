local bint = require(".bint")(256)

-- Helper function to serialize keys
local function serializeKey(k)
  if bint.isbint(k) then
    return "@bint:" .. tostring(k)
  elseif type(k) == "string" then
    return k
  elseif type(k) == "number" then
    return "@number:" .. tostring(k)
  elseif type(k) == "boolean" then
    return "@boolean:" .. tostring(k)
  elseif k == nil then
    return "@nil"
  else
    return nil -- Discard unserializable keys
  end
end

-- Helper function to reconstruct keys
local function reconstructKey(k)
  if type(k) == "string" then
    if k:sub(1, 6) == "@bint:" then
      return bint.new(k:sub(7))
    elseif k:sub(1, 8) == "@number:" then
      return tonumber(k:sub(9))
    elseif k:sub(1, 9) == "@boolean:" then
      return k:sub(10) == "true"
    elseif k == "@nil" then
      return nil
    else
      return k
    end
  else
    return k
  end
end

-- Main serialization function with cycle detection
local function serializeValue(obj, seen)
  if seen == nil then
    seen = {}
  end

  -- Handle basic types
  if bint.isbint(obj) then
    return { __bint = tostring(obj) }
  elseif type(obj) == "string" or type(obj) == "number" or type(obj) == "boolean" or obj == nil then
    return obj
  elseif type(obj) == "table" then
    if seen[obj] then
      -- Circular reference detected; we can represent it as a special value or skip it
      return "__circular_reference__"
      -- Alternatively, you could return nil or some placeholder
    end
    seen[obj] = true
    local newObj = {}
    for k, v in pairs(obj) do
      local serializedKey = serializeKey(k)
      local serializedValue = serializeValue(v, seen)

      if serializedKey ~= nil and serializedValue ~= nil then
        newObj[serializedKey] = serializedValue
      end
    end
    seen[obj] = nil -- Allow garbage collection
    return newObj
  else
    -- Discard functions, userdata, threads, and other types
    return nil
  end
end

-- Function to reconstruct serialized values back to their original form
local function reconstructValue(obj, seen)
  if seen == nil then
    seen = {}
  end

  if type(obj) == "table" then
    if obj.__bint then
      return bint.new(obj.__bint)
    elseif obj == "__circular_reference__" then
      -- Handle circular references appropriately; this may require custom logic
      -- For this example, we'll return nil
      return nil
    elseif seen[obj] then
      -- Circular reference detected during reconstruction
      return seen[obj]
    else
      local newObj = {}
      seen[obj] = newObj
      for k, v in pairs(obj) do
        local originalKey = reconstructKey(k)
        local reconstructedValue = reconstructValue(v, seen)
        if originalKey ~= nil then
          newObj[originalKey] = reconstructedValue
        end
      end
      return newObj
    end
  else
    -- Basic types are returned as-is
    return obj
  end
end

return {
  serialize = serializeValue,
  reconstruct = reconstructValue,
}
