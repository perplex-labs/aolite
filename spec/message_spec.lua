local aolite = require("aolite")
local log = require(".log")

local PROCESS_SRC = [[
Handlers.add("BroadcastHandler", "Broadcast", function(msg)
  ao.send({ Target = msg.Recipient, Action = "Broadcast", Data = msg.Data })
  ao.send({ Target = msg.From, Action = "Broadcast-Success", Data = msg.Data })
end)
]]

describe("process message sending", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("chat-process", PROCESS_SRC, {
      { name = "On-Boot", value = "Data" },
    })
    aolite.spawnProcess("user-process-1", nil)
    aolite.spawnProcess("user-process-2", nil)
  end)

  it("can send two messages in one execution", function()
    aolite.send({
      From = "user-process-1",
      Target = "chat-process",
      Action = "Broadcast",
      Recipient = "user-process-2",
      Data = "Hello world",
    })

    local res1 = aolite.getLastMsg("user-process-1")
    log.debug("getLastMsg(user-process-1): ", res1)
    assert.is_not_nil(res1)
    assert.are.equal("Broadcast-Success", res1.Action)
    assert.are.equal("Hello world", res1.Data)

    local res2 = aolite.getLastMsg("user-process-2")
    log.debug("getLastMsg(user-process-2): ", res2)
    assert.is_not_nil(res2)
    assert.are.equal("Broadcast", res2.Action)
    assert.are.equal("Hello world", res2.Data)
  end)
end)
