local aolite = require("aolite")

describe("module & From-Module tag", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("user-process-1", nil, { ["Module"] = "module-1" })
    aolite.spawnProcess("user-process-2", nil, { ["Module"] = "module-2" })
  end)

  it("has From-Module tag in the message", function()
    aolite.send({
      From = "user-process-1",
      Target = "user-process-1",
    })

    local res = aolite.getLastMsg("user-process-1")
    assert.is_not_nil(res)
    assert.are.equal("module-1", res.Tags["From-Module"])
  end)

  it("From-Module has the correct value", function()
    aolite.send({
      From = "user-process-2",
      Target = "user-process-1",
      Data = "Hello world",
    })

    local res = aolite.getLastMsg("user-process-1")
    assert.is_not_nil(res)
    assert.are.equal("module-2", res.Tags["From-Module"])
  end)
end)
