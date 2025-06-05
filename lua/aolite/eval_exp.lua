-- Common evaluation function
local function evaluateExpression(expression, chunkname)
  chunkname = chunkname or "Eval"

  -- Set up the environment for evaluation
  local env = {}
  setmetatable(env, { __index = _G }) -- Inherit from the process's global environment

  local func, err = load("return " .. tostring(expression), chunkname, "t", env)

  if not func then
    -- Try without "return", in case it's a statement
    func, err = load(expression, chunkname, "t", env)
  end

  if not func then
    -- Compilation error
    return false, "Compilation error: " .. tostring(err)
  end

  -- Execute the function and capture the result
  local status, result = pcall(func)

  if status then
    return true, result
  else
    return false, "Runtime error: " .. tostring(result)
  end
end

return {
  eval = evaluateExpression,
}
