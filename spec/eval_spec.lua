local aolite = require("aolite")

describe("aolite.eval", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("proc", "return true", { ["On-Boot"] = "Data" })
  end)

  it("evaluates expressions", function()
    local result = aolite.eval("proc", "return 1 + 2")
    assert.are.equal(3, result)
  end)

  it("returns an error on failure", function()
    assert.has_error(function()
      aolite.eval("proc", "error('boom')")
    end)
  end)
end)

describe("eval Handlers", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("proc", nil)
  end)

  it("loaded eval handler", function()
    local handlers = aolite.eval("proc", "return Handlers.list")
    local evalHandler = nil
    for _, handler in ipairs(handlers) do
      if handler.name == "_eval" then
        evalHandler = handler
        break
      end
    end
    assert.is_not_nil(evalHandler)
  end)

  it("evaluates expressions inside processes", function()
    aolite.send({
      From = "proc",
      Target = "proc",
      Action = "Eval",
      Data = "Send({ Target = 'proc', Data = 'Hello, world!' })",
    })

    local lastMsg = aolite.getLastMsg("proc")
    assert.are.equal("Hello, world!", lastMsg.Data)
  end)
end)
