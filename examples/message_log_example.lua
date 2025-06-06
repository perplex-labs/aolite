local ao = require("aolite")

-- Log all messages exchanged between processes to a file
local logPath = "./messages.log"
ao.setMessageLog(logPath)
print("Log file:", ao.getMessageLog())

-- Process source with a simple Ping handler
local source = [[
print("Process loaded with ID: " .. ao.id)
Handlers.add("Ping", function(msg)
  msg.reply({ Action = "Pong" })
end)
]]

-- Spawn the process from the source string (On-Boot tag required)
local pid = "logger"
ao.spawnProcess(pid, source, { { name = "On-Boot", value = "Data" } })

-- Send a Ping message and process it automatically
ao.send({ From = pid, Target = pid, Action = "Ping" })

-- Retrieve the reply
local resp = ao.getLastMsg(pid)
print("Response from process:", resp.Action)
