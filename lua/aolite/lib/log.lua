local bint = require("aolite.lib.bint")(256)

local function bintToDecimalStr(number, precision)
  assert(bint.isbint(number), "bintToDecimalString: number must be a bint")
  assert(precision and precision >= 0, "bintToDecimalString: precision must be non-negative")

  local isNegative = bint.isneg(number)
  if isNegative then
    number = -number
  end

  local factor = bint.ipow(bint(10), bint(precision))
  local integerPart = number // factor
  local fractionalPart = number % factor


  if integerPart == bint.zero() and fractionalPart == bint.zero() then
    isNegative = false
  end

  local integerStr = tostring(integerPart)
  local fractionalStr = tostring(fractionalPart)


  if precision > 0 then
    fractionalStr = string.rep("0", precision - #fractionalStr) .. fractionalStr
  end

  local result = ""
  if precision == 0 then
    result = integerStr
  else
    fractionalStr = fractionalStr:gsub("0+$", "")
    if #fractionalStr == 0 then
      result = integerStr
    else
      result = integerStr .. "." .. fractionalStr
    end
  end

  if isNegative then
    result = "-" .. result
  end

  return result
end

local function serializeData(data)
  if bint.isbint(data) then
    return tostring(data)
  elseif type(data) == "table" then
    local serialized = {}
    local data_table = data
    for key, value in pairs(data_table) do
      serialized[key] = serializeData(value)
    end
    return serialized
  else
    return tostring(data)
  end
end

local function hr(number, denomination, decimals)
  assert(bint.isbint(number), "hr: number must be a bint, not " .. tostring(number))
  assert(denomination and denomination >= 0, "hr: denomination must be defined and non-negative")

  local decimalStr = bintToDecimalStr(number, denomination)

  if decimals then
    local integerPart, fractionalPart = decimalStr:match("^(-?%d+)%.?(%d*)$")
    fractionalPart = fractionalPart or ""

    if decimals == 0 then
      local firstDecimalDigit = tonumber(fractionalPart:sub(1, 1) or "0")
      if firstDecimalDigit and firstDecimalDigit >= 5 then
        integerPart = tostring(tonumber(integerPart) + (integerPart:sub(1, 1) == "-" and -1 or 1))
      end
      return integerPart
    else
      local desiredFraction = fractionalPart:sub(1, decimals)

      local nextDigit = tonumber(fractionalPart:sub(decimals + 1, decimals + 1) or "0")
      if nextDigit and nextDigit >= 5 then
        local roundedFraction = tonumber(desiredFraction) + 1
        desiredFraction = tostring(roundedFraction)

        if #desiredFraction > decimals then
          desiredFraction = desiredFraction:sub(2)
          integerPart = tostring(tonumber(integerPart) + (integerPart:sub(1, 1) == "-" and -1 or 1))
        end
      end

      desiredFraction = desiredFraction .. string.rep("0", decimals - #desiredFraction)
      return integerPart .. "." .. desiredFraction
    end
  else
    return decimalStr
  end
end

local function printTable(t, indent, isTopLevel)
  indent = indent or 0
  if isTopLevel == nil then
    isTopLevel = true
  end

  if isTopLevel then
    print(string.rep("  ", indent))
    indent = indent + 1
  end

  for k, v in pairs(t) do
    if type(v) == "table" and not bint.isbint(v) then
      print(string.rep("  ", indent) .. tostring(k) .. " = {")
      printTable(v, indent + 1, false)
      print(string.rep("  ", indent) .. "}")
    else
      local valueStr = bint.isbint(v) and tostring(v) or tostring(v)
      print(string.rep("  ", indent) .. tostring(k) .. " = " .. valueStr)
    end
  end

  if isTopLevel then
    indent = indent - 1
    print(string.rep("  ", indent))
  end
end

local function createPrintFunction(level)
  return function(...)
    if level <= (_G.PrintVerb or 0) then
      local args = { ... }
      for _, v in ipairs(args) do
        if type(v) == "table" and not bint.isbint(v) then
          printTable(v)
        else
          print(tostring(v))
        end
      end
    end
  end
end

return {
  serializeData = serializeData,
  hr = hr,
  debug = createPrintFunction(2),
  warn = createPrintFunction(1),
  info = createPrintFunction(0),
}
