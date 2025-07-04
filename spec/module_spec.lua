local aolite = require("aolite")
local utils = require(".utils")
local log = require(".log")

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

  it("From-Module and Module properly set on spawned process", function()
    local spawnId = aolite.eval(
      "user-process-1",
      [[
        local resp = ao.spawn("other-module", {
          Tags = {
            ['Authority'] = ao.authorities[1],
          },
        }).receive()

        return resp.Process
      ]]
    )

    local processEnv = aolite.eval(spawnId, "return ao.env.Process")
    log.debug("processEnv", processEnv)
    assert.is_not_nil(processEnv)
    assert.are.equal("module-1", processEnv.Tags["From-Module"])
    assert.are.equal("other-module", processEnv.Tags["Module"])
  end)

  it("keeps Module and From-Module after two messages", function()
    -- parent spawns a child written in a different module
    local childId = aolite.eval(
      "user-process-1",
      [[
        local resp = ao.spawn("other-module", {
          Tags = { ['Authority'] = ao.authorities[1] },
        }).receive()
        return resp.Process
      ]]
    )

    -- first and second message to the child (bug used to surface after the 2nd)
    aolite.send({ From = "user-process-1", Target = childId, Data = "ping-1" })
    aolite.send({ From = "user-process-1", Target = childId, Data = "ping-2" })

    -- inspect the process environment of the child
    local tags = aolite.eval(childId, "return ao.env.Process.Tags")
    assert.is_not_nil(tags, "Tags table should exist")
    assert.are.equal("other-module", tags["Module"])
    assert.are.equal("module-1", tags["From-Module"])
  end)
end)

describe("custom Lua module loader", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("user-proc", nil)
    aolite.spawnProcess("echo-proc", nil, { ["Module"] = "spec.modules.module_echo" })
  end)

  it("loads the custom module and processes a message", function()
    local payload = "Hello from test"

    aolite.send({
      From = "user-proc",
      Target = "echo-proc",
      Data = payload,
      Action = "Ping",
    })

    -- The echo module should reply back to the sender ("user-proc").
    local res = aolite.getLastMsg("user-proc")
    assert.is_not_nil(res)
    assert.are.equal(payload, res.Data)
    assert.are.equal(
      "spec.modules.module_echo",
      res.Tags["From-Module"],
      "From-Module tag should reflect the custom module id"
    )
  end)
end)

describe("module returning Spawns table", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("spawner-proc", nil, { ["Module"] = "spec.modules.module_spawn" })
  end)

  it("converts outbox.Spawns into a Spawned message", function()
    aolite.send({ From = "spawner-proc", Target = "spawner-proc", Action = "Spawn" })

    local msg = aolite.getLastMsg("spawner-proc", { Action = "Spawned" })
    assert.is_not_nil(msg)
    assert.are.equal("spawner-proc", msg.From)
    assert.are.equal("Spawned", msg.Action)
    -- Since we are not using the default AO module,
    -- tags are not parsed and put into a map.
    local fromModule = utils.find(function(t)
      return t.name == "From-Module"
    end, msg.Tags).value
    assert.are.equal("spec.modules.module_spawn", fromModule)
  end)

  it("converts outbox.Spawns into a Spawned message", function()
    aolite.send({ From = "spawner-proc", Target = "spawner-proc", Action = "Spawn" })

    local msg = aolite.getLastMsg("spawner-proc", { Action = "Spawned" })
    local processId = msg.Process

    aolite.spawnProcess("user", nil)
    aolite.send({ From = "user", Target = processId, Action = "Spawn" })

    local res = aolite.getLastMsg(processId)
    assert.is_not_nil(res)
    assert.are.equal("Spawned", res.Action)
  end)
end)
