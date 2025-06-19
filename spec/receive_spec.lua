local aolite = require("aolite")
local log = require(".log")

local PING_PONG_SRC = [[
Handlers.add("PingHandler", "Ping", function(msg)
  msg.reply({ Action = "Pong", Data = msg.Data })
end)
]]

-- uses ao.send().receive()
local PLAYER_SRC = [[
Handlers.add("PlayHandler", "Play", function(msg)
  local gameId = msg.Tags.GameId
  local result = ao.send({ Target = gameId, Action = "Ping", Data = ao.id }).receive()
  ao.send({ Target = result.Data, Action = "Success" })
end)
]]

-- uses global Receive()
local PLAYER_GLOBAL_SRC = [[
Handlers.add("PlayGlobalHandler", "Play-Global", function(msg)
  local gameId = msg.Tags.GameId
  ao.send({ Target = gameId, Action = "Ping", Data = ao.id })
  local result = Receive({ Action = "Pong" })
  ao.send({ Target = result.Data, Action = "Success-Global" })
end)
]]

describe("ao.send().receive() + Receive()", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("game-process", PING_PONG_SRC, {
      { name = "On-Boot", value = "Data" },
    })
  end)

  it("ao.send().receive() receives reply", function()
    aolite.spawnProcess("player-process", PLAYER_SRC, {
      { name = "On-Boot", value = "Data" },
    })

    aolite.send({
      From = "player-process",
      Target = "player-process",
      Action = "Play",
      Tags = { GameId = "game-process" },
    })
    local res = aolite.getLastMsg("player-process")
    assert.is_not_nil(res)
    assert.are.equal("Success", res.Action)
  end)

  it("global Receive receives reply", function()
    aolite.spawnProcess("player-process", PLAYER_GLOBAL_SRC, {
      { name = "On-Boot", value = "Data" },
    })

    aolite.send({
      From = "player-process",
      Target = "player-process",
      Action = "Play-Global",
      Tags = { GameId = "game-process" },
    })
    local res = aolite.getLastMsg("player-process")
    assert.is_not_nil(res)
    assert.are.equal("Success-Global", res.Action)
  end)
end)
