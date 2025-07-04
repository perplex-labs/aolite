local serialize = require(".serialize")
local json = require("json")
local eval = require("aolite.eval_exp")

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

-- NOTE: This is simply to silence the EvalResponse message generated above
--       (prevents the default handler from printing a new message received)
Handlers.prepend("EvalResponseHandler", "EvalResponse", function() end)
