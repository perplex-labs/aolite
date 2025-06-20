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
