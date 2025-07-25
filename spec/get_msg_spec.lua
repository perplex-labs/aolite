local aolite = require("aolite")

local PING_SRC = [[
Handlers.add("Ping", function(msg)
  msg.reply({ Action = "Pong", Data = msg.Data })
end)
]]

describe("aolite.getMsgById and getMsg", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("sender", "return true", { ["On-Boot"] = "Data" })
    aolite.spawnProcess("receiver", PING_SRC, { ["On-Boot"] = "Data" })
  end)

  it("fetches a message by ID", function()
    aolite.send({
      From = "sender",
      Target = "receiver",
      Action = "Ping",
      Data = "hello",
      Tags = { { name = "Reference", value = "1" } },
    })

    local resp = aolite.getLastMsg("sender")
    assert.is_not_nil(resp)

    local fetched = aolite.getMsgById(resp.Id)
    assert.is_not_nil(fetched)
    assert.are.same(resp, fetched)
  end)

  it("finds messages matching a spec across processes", function()
    aolite.send({
      From = "sender",
      Target = "receiver",
      Action = "Ping",
      Data = "world",
      Tags = { { name = "Reference", value = "2" } },
    })

    local results = aolite.getMsgs({ Action = "Pong", Data = "world" })
    assert.are.equal(1, #results)
    assert.are.equal("Pong", results[1].Action)
  end)
end)
