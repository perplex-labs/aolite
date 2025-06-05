--- The Boot module provides functionality for booting the process. Returns the boot function.
-- @module boot

-- This is for aop6 Boot Loader
-- See: https://github.com/permaweb/aos/issues/342
-- For the Process as the first Message, if On-Boot
-- has the value 'data' then evaluate the data
-- if it is a tx id, then download and evaluate the tx

local eval = require("aolite.eval_exp")
local drive = { _version = "0.0.1" }

function drive.getData(txId)
  local file = io.open("./data/" .. txId)
  if not file then
    return nil, "File not found!"
  end
  local contents = file:read("*all")
  file:close()
  return contents
end

--- The boot function.
-- If the message has no On-Boot tag, do nothing.
-- If the message has an On-Boot tag with the value 'Data', then evaluate the message.
-- If the message has an On-Boot tag with a tx id, then download and evaluate the tx data.
-- @function boot
-- @param ao The ao environment object
-- @see eval
return function(ao)
  return function(msg)
    if msg.Tags["On-Boot"] == nil then
      return
    end
    if msg.Tags["On-Boot"] == "Data" then
      eval.eval(msg)
    else
      local loadedVal = drive.getData(msg.Tags["On-Boot"])
      -- log.debug("Loaded: ", loadedVal)
      eval.eval(loadedVal, "Eval")
    end
  end
end
