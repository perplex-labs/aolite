local aolite = require("aolite")
local bint = require(".bint")(256)

describe("bint integration", function()
  before_each(function()
    aolite.clearAllProcesses()
    local src = [[
      local bint = require(".bint")(256)
      GlobalBint = bint(10)
    ]]
    aolite.spawnProcess("proc", src, {
      { name = "On-Boot", value = "Data" },
    })
  end)

  it("serializes and reconstructs bints from eval", function()
    local result = aolite.eval("proc", "GlobalBint")
    assert.is_true(bint.isbint(result))
    assert.is_true(bint.eq(result, bint.new(10)))
  end)
end)
