local aolite = require("aolite")

local PING_SRC = [[
Handlers.add("Ping", function(msg)
  msg.reply({ Action = "Pong", Data = msg.Data })
end)
]]

describe("process interactions", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.setAutoSchedule(true)
    aolite.spawnProcess("sender", "return true", {
      { name = "On-Boot", value = "Data" },
    })
    aolite.spawnProcess("receiver", PING_SRC, {
      { name = "On-Boot", value = "Data" },
    })
  end)

  it("sends and receives messages", function()
    aolite.send({
      From = "sender",
      Target = "receiver",
      Action = "Ping",
      Data = "hello",
      Tags = { { name = "Reference", value = "1" } },
    })

    local resp = aolite.getLastMsg("sender")
    assert.is_not_nil(resp)
    assert.are.equal("Pong", resp.Action)
    assert.are.equal("hello", resp.Data)
    assert.are.equal("receiver", resp.From)
  end)

  it("supports manual scheduling", function()
    aolite.setAutoSchedule(false)
    aolite.send({
      From = "sender",
      Target = "receiver",
      Action = "Ping",
      Data = "hi",
      Tags = { { name = "Reference", value = "1" } },
    })

    -- no scheduler run yet
    assert.is_nil(aolite.getLastMsg("sender"))
    local queued = aolite.listQueueMessages("receiver")
    assert.are.equal(1, #queued)

    aolite.runScheduler()

    local resp = aolite.getLastMsg("sender")
    assert.is_not_nil(resp)
    assert.are.equal("Pong", resp.Action)
    assert.are.equal("hi", resp.Data)
  end)

  it("can reorder queued messages", function()
    aolite.setAutoSchedule(false)

    aolite.send({
      From = "sender",
      Target = "receiver",
      Action = "Ping",
      Data = "first",
      Tags = { { name = "Reference", value = "1" } },
    })
    aolite.send({
      From = "sender",
      Target = "receiver",
      Action = "Ping",
      Data = "second",
      Tags = { { name = "Reference", value = "2" } },
    })

    local q = aolite.listQueueMessages("receiver")
    assert.are.equal(2, #q)
    -- reverse order
    local order = { q[2].Id, q[1].Id }
    aolite.reorderQueue("receiver", order)

    aolite.runScheduler()

    local first = aolite.getFirstMsg("sender")
    local last = aolite.getLastMsg("sender")
    assert.are.equal("second", first.Data)
    assert.are.equal("first", last.Data)
  end)
end)
