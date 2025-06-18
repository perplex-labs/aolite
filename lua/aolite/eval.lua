local serialize = require(".serialize")
local json = require("json")
local eval = require("aolite.eval_exp")

-- Eval Handler
Handlers.add("_eval", "Eval", function(msg)
  local expression = msg.Data

  local status, outputOrError = eval.eval(expression, "Eval")

  if status then
    local output = outputOrError
    if HANDLER_PRINT_LOGS and output then
      table.insert(HANDLER_PRINT_LOGS, type(output) == "table" and stringify.format(output) or tostring(output))
    else
      -- Set result in ao.outbox.Output (Left for backwards compatibility)
      ao.outbox.Output = {
        json = type(output) == "table" and (pcall(function()
          return json.encode(output)
        end) and output or "undefined"),
        data = {
          output = type(output) == "table" and stringify.format(output) or tostring(output),
          prompt = Prompt(),
        },
        prompt = Prompt(),
      }
    end
  else
    local err = outputOrError
    ao.outbox.Error = err
  end
end)

-- Eval Request Handler
Handlers.add("EvalRequestHandler", "EvalRequest", function(msg)
  local expression = msg.Expression or msg.Data

  local status, resultOrError = eval.eval(expression, "EvalRequest")

  if status then
    local result = resultOrError
    -- Serialization of the result
    local serializedResult = json.encode(serialize.serialize(result, {}))
    -- Send the result back to the requester
    msg.reply({
      Action = "EvalResponse",
      Expression = expression,
      Data = serializedResult,
    })
  else
    local err = resultOrError
    -- Runtime error during execution
    msg.reply({
      Action = "EvalResponse",
      Expression = expression,
      Error = err,
    })
  end
end)
