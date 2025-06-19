local aolite = require("aolite")

describe("token blueprint", function()
  describe("token spawning", function()
    before_each(function()
      aolite.clearAllProcesses()
    end)

    it("can be spawned with no tags", function()
      aolite.spawnProcess("token-process", "spec.blueprints.token")
      local res = aolite.eval("token-process", "return Ticker")
      assert.is_not_nil(res)
    end)

    it("can be spawned with tags", function()
      aolite.spawnProcess("token-process", "spec.blueprints.token", {
        Ticker = "TT",
        Name = "TestToken",
        Denomination = "18",
      })
      assert.are.equal("TT", aolite.eval("token-process", "return Ticker"))
      assert.are.equal("TestToken", aolite.eval("token-process", "return Name"))
      assert.are.equal("18", aolite.eval("token-process", "return Denomination"))
    end)
  end)

  describe("token handlers", function()
    before_each(function()
      aolite.clearAllProcesses()
      aolite.spawnProcess("token-process", "spec.blueprints.token")
      aolite.spawnProcess("user-process", nil)
    end)

    it("info handler", function()
      aolite.send({
        From = "user-process",
        Target = "token-process",
        Action = "Info",
      })
      local res = aolite.getLastMsg("user-process")
      assert.is_not_nil(res)
      assert.are.equal("token-process", res.From)
      assert.are.equal("PNTS", res.Tags.Ticker)
      assert.are.equal("Points Coin", res.Tags.Name)
      assert.are.equal("12", res.Tags.Denomination)
    end)

    it("balance handler", function()
      aolite.send({
        From = "user-process",
        Target = "token-process",
        Action = "Balance",
      })
      local res = aolite.getLastMsg("user-process")
      assert.is_not_nil(res)
      assert.are.equal("token-process", res.From)
      assert.are.equal("0", res.Tags.Balance)
    end)
  end)
end)
