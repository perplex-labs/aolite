local aolite = require("aolite")

local PING_SRC = [[
Handlers.add("Ping", function(msg)
  msg.reply({ Action = "Pong", Data = msg.Data })
end)
]]

describe("scheduler queue reordering", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("p1", PING_SRC, { ["On-Boot"] = "Data" })
    aolite.spawnProcess("p2", PING_SRC, { ["On-Boot"] = "Data" })
    aolite.setAutoSchedule(false)
  end)

  it("reorders messages for multiple processes", function()
    -- queue messages to both processes
    aolite.send({ From = "p1", Target = "p2", Action = "Ping", Data = "A" })
    aolite.send({ From = "p1", Target = "p2", Action = "Ping", Data = "B" })
    aolite.send({ From = "p2", Target = "p1", Action = "Ping", Data = "1" })
    aolite.send({ From = "p2", Target = "p1", Action = "Ping", Data = "2" })

    local q1 = aolite.listQueueMessages("p1")
    local q2 = aolite.listQueueMessages("p2")
    assert.are.equal(2, #q1)
    assert.are.equal(2, #q2)

    -- reverse both queues
    aolite.reorderQueue("p1", { q1[2].Id, q1[1].Id })
    aolite.reorderQueue("p2", { q2[2].Id, q2[1].Id })

    aolite.runScheduler()

    -- check that replies arrived in the new order
    local firstP1 = aolite.getFirstMsg("p1", { From = "p2", Action = "Pong" })
    local lastP1 = aolite.getLastMsg("p1", { From = "p2", Action = "Pong" })
    assert.are.equal("B", firstP1.Data)
    assert.are.equal("A", lastP1.Data)

    local firstP2 = aolite.getFirstMsg("p2", { From = "p1", Action = "Pong" })
    local lastP2 = aolite.getLastMsg("p2", { From = "p1", Action = "Pong" })
    assert.are.equal("2", firstP2.Data)
    assert.are.equal("1", lastP2.Data)
  end)
end)
