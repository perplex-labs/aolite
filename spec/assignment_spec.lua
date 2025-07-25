local aolite = require("aolite")
local json = require("json")

local ASSIGNER_SRC = [[
  local json = require("json")
  Handlers.add("assign", "Assign-Test", function(msg)
    local targets = json.decode(msg.Tags.Targets)
    ao.assign({ Message = msg.Id, Processes = targets })
  end)
]]

local RECEIVER_SRC = [[
  ao.addAssignable("Assign-Test", {
    Action = "Assign-Test",
    From = "assigner",
  })
  Handlers.add("receiver", "Assign-Test", function(msg)
    MY_STATE = msg.Data
  end)
]]

describe("ao.assign", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("assigner", ASSIGNER_SRC, { ["On-Boot"] = "Data" })
  end)

  it("fails if no ao.addAssignable was called", function()
    aolite.spawnProcess("receiver", nil)
    aolite.send({
      From = "assigner",
      Target = "assigner",
      Targets = json.encode({ "receiver" }),
      Action = "Assign-Test",
      Data = "Hello, world!",
    })

    local lastMsg = aolite.getLastMsg("assigner")
    assert.are.equal("receiver", lastMsg.From)
    assert.are.equal("assigner", lastMsg.Target)
    assert.are.equal("Assignment is not trusted by this process!", lastMsg.Data)
  end)

  it("can assign a message to multiple processes", function()
    aolite.spawnProcess("receiver-1", RECEIVER_SRC, { ["On-Boot"] = "Data" })
    aolite.spawnProcess("receiver-2", RECEIVER_SRC, { ["On-Boot"] = "Data" })

    aolite.send({
      From = "assigner",
      Target = "assigner",
      Targets = json.encode({ "receiver-1", "receiver-2" }),
      Action = "Assign-Test",
      Data = "Hello, world!",
    })

    local lastMsg1 = aolite.getLastMsg("receiver-1")
    local lastMsg2 = aolite.getLastMsg("receiver-2")
    assert.are.equal("Assign-Test", lastMsg1.Action)
    assert.are.equal("Assign-Test", lastMsg2.Action)
    assert.are.equal(lastMsg1.Id, lastMsg2.Id)

    local state1 = aolite.eval("receiver-1", "MY_STATE")
    local state2 = aolite.eval("receiver-2", "MY_STATE")
    assert.are.equal("Hello, world!", state1)
    assert.are.equal("Hello, world!", state2)
  end)
end)
