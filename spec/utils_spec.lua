local utils = require("aolite.lib.utils")

describe("utils", function()
  it("matches patterns and specs", function()
    local msg = { Action = "Ping", Foo = "Bar" }
    assert.is_true(utils.matchesPattern("Ping", msg.Action, msg))
    assert.is_true(utils.matchesSpec(msg, { Action = "Ping" }))
    assert.is_false(utils.matchesSpec(msg, { Action = "Pong" }))
  end)

  it("curries functions", function()
    local function add(a, b, c)
      return a + b + c
    end
    local curried = utils.curry(add)
    assert.are.equal(6, curried(1)(2)(3))
  end)

  it("maps and filters", function()
    local data = {1, 2, 3, 4}
    local doubled = utils.map(function(x) return x * 2 end, data)
    assert.are.same({2,4,6,8}, doubled)

    local evens = utils.filter(function(x) return x % 2 == 0 end, doubled)
    assert.are.same({2,4,6,8}, evens)
  end)
end)
