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
    aolite.spawnProcess("game-process", PING_PONG_SRC, { ["On-Boot"] = "Data" })
  end)

  it("ao.send().receive() receives reply", function()
    aolite.spawnProcess("player-process", PLAYER_SRC, { ["On-Boot"] = "Data" })

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
    aolite.spawnProcess("player-process", PLAYER_GLOBAL_SRC, { ["On-Boot"] = "Data" })

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

describe("ao.spawn().receive()", function()
  before_each(function()
    aolite.clearAllProcesses()
  end)

  it("ao.spawn().receive() receives reply", function()
    aolite.spawnProcess("process", nil)
    aolite.eval(
      "process",
      [=[
          local resp = ao.spawn(ao._module, {
            Tags = {
              ['Authority'] = ao.authorities[1],
              ['On-Boot'] = 'Data',
            },
            Data = [[
              MY_STATE = true
            ]]
          }).receive()
          CHILD_PROCESS_ID = resp.Process
        ]=]
    )

    local childProcessId = aolite.eval("process", "return CHILD_PROCESS_ID")
    assert.is_not_nil(childProcessId)

    local state = aolite.eval(childProcessId, "return MY_STATE")
    assert.is_true(state)
  end)

  it("ao.spawn().receive() + ao.send().receive() on spawned process", function()
    aolite.spawnProcess("process", nil)
    aolite.eval(
      "process",
      [=[
        local spawnRes = ao.spawn(ao._module, {
          Tags = {
            ['Authority'] = ao.authorities[1],
            ['On-Boot'] = 'Data',
          },
          Data = [[
            Handlers.add("PingHandler", "Ping", function(msg)
              msg.reply({ Action = "Pong", Data = msg.Data })
            end)
          ]]
        }).receive()
        CHILD_PROCESS_ID = spawnRes.Process
        local sendRes = ao.send({
          From = Owner,
          Target = CHILD_PROCESS_ID,
          Action = "Ping",
          Data = ao.id
        }).receive()
        SUCCESS = assert(sendRes.Action == "Pong", "Expected Pong, got " .. sendRes.Action)
      ]=]
    )

    local childProcessId = aolite.eval("process", "return CHILD_PROCESS_ID")
    assert.is_not_nil(childProcessId)

    local success = aolite.eval("process", "return SUCCESS")
    assert.is_true(success)
  end)
end)
