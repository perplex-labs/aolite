local ao = require("aolite")

-- Create two processes that just log messages
local source = [[
Handlers.add("Print", function(msg)
  print(ao.id .. " received: " .. (msg.Data or ""))
end)
]]

local p1, p2 = "proc1", "proc2"
ao.spawnProcess(p1, source, { { name = "On-Boot", value = "Data" } })
ao.spawnProcess(p2, source, { { name = "On-Boot", value = "Data" } })

-- Disable auto scheduling to control when messages are processed
ao.setAutoSchedule(false)

-- Queue some messages
ao.send({ From = p1, Target = p2, Action = "Print", Data = "Hello" })
ao.send({ From = p2, Target = p1, Action = "Print", Data = "World" })

print("No messages processed yet")

-- Run the scheduler manually
ao.runScheduler()
