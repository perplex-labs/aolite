local ao = require("aolite")

-- Processes simply print any messages they receive
local source = [[
Handlers.add("Print", function(msg)
  print(ao.id .. " received: " .. (msg.Data or ""))
  -- echo back to sender so we can observe ordering
  msg.reply({ Action = "Ack", Data = msg.Data })
end)
]]

local p1, p2 = "proc1", "proc2"
local boot = { { name = "On-Boot", value = "Data" } }
ao.spawnProcess(p1, source, boot)
ao.spawnProcess(p2, source, boot)

-- We'll control the scheduler manually
ao.setAutoSchedule(false)

-- Queue several messages in both directions
ao.send({ From = p1, Target = p2, Action = "Print", Data = "one" })
ao.send({ From = p1, Target = p2, Action = "Print", Data = "two" })
ao.send({ From = p2, Target = p1, Action = "Print", Data = "alpha" })
ao.send({ From = p2, Target = p1, Action = "Print", Data = "beta" })

print("== Original queues ==")
local q1 = ao.listQueueMessages(p1)
for i, msg in ipairs(q1) do
  print("p1[" .. i .. "]: " .. msg.Data)
end
local q2 = ao.listQueueMessages(p2)
for i, msg in ipairs(q2) do
  print("p2[" .. i .. "]: " .. msg.Data)
end

-- Reverse the order for each queue
ao.reorderQueue(p1, { q1[2].Id, q1[1].Id })
ao.reorderQueue(p2, { q2[2].Id, q2[1].Id })

print("== Reordered queues ==")
for i, msg in ipairs(ao.listQueueMessages(p1)) do
  print("p1[" .. i .. "]: " .. msg.Data)
end
for i, msg in ipairs(ao.listQueueMessages(p2)) do
  print("p2[" .. i .. "]: " .. msg.Data)
end

-- Process all messages
ao.runScheduler()
