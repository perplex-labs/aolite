local ao = require("aolite")

-- Spawn a simple process with a Ping handler
local source = [[
Handlers.add("Ping", function(msg)
  msg.reply({ Action = "Pong" })
end)
]]

local procId = "pinger"
-- Note: On-Boot tag is mandatory when loading from string
local tags = { { name = "On-Boot", value = "Data" } }
ao.spawnProcess(procId, source, tags)

-- Send a Ping message
local msg = { From = procId, Target = procId, Action = "Ping" }
ao.send(msg)

-- Retrieve the response
local resp = ao.getLastMsg(procId)
print("Process replied with:", resp.Action)
