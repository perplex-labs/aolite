local aolite = require("aolite")
local json = require("json")

local LOG_PATH = "spec/tmp_messages.log"

local PING_SRC = [[
Handlers.add("Ping", function(msg)
  msg.reply({ Action = "Pong", Data = msg.Data })
end)
]]

describe("message logging", function()
  before_each(function()
    os.remove(LOG_PATH)
    aolite.clearAllProcesses()
    aolite.setMessageLog(LOG_PATH)
    aolite.spawnProcess("logger", PING_SRC, { ["On-Boot"] = "Data" })
  end)

  after_each(function()
    aolite.setMessageLog(nil)
    os.remove(LOG_PATH)
  end)

  it("writes queued messages to a file", function()
    aolite.send({
      From = "logger",
      Target = "logger",
      Action = "Ping",
      Data = "hello",
      Tags = { { name = "Reference", value = "1" } },
    })

    local file = assert(io.open(LOG_PATH, "r"))
    local lines = {}
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()

    assert.is_true(#lines >= 2)
    local msg = json.decode(lines[2])
    assert.are.equal("hello", msg.Data)
    assert.are.equal("logger", msg.Target)

    local action
    for _, tag in ipairs(msg.Tags or {}) do
      if tag.name == "Action" then
        action = tag.value
      end
    end
    assert.are.equal("Ping", action)
  end)
end)
