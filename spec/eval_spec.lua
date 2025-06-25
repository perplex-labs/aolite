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

  it("persists state between evaluations", function()
    aolite.eval("proc", "Toto = 5")
    local result = aolite.eval("proc", "return Toto")
    assert.are.equal(5, result)
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
      Data = "Toto = 7; ao.send({ Target = 'proc', Data = 'Hello, world!' })",
    })

    local lastMsg = aolite.getLastMsg("proc")
    assert.are.equal("Hello, world!", lastMsg.Data)
  end)
end)

describe("subprocess eval", function()
  before_each(function()
    aolite.clearAllProcesses()
    aolite.spawnProcess("proc", nil)
    aolite.eval(
      "proc",
      [=[
      local resp = ao.spawn(ao._module, {
        Tags = {
          ['Authority'] = ao.authorities[1],
          ['On-Boot'] = 'Data',
        },
        Data = [[
          Handlers.prepend("EvalPrepend", function(message)
            if message.Action == "Eval" and message.From == Owner then
              return "continue"
            end
            return false
          end, function(message)
            -- Only reply if I not an assignment to prevent spam
            if not ao.isAssignment(message) then
              message.reply({
                Action = "Eval-Msg-Id",
                Tags = {
                  ['Msg-Id'] = message.Id,
                }
              })
            end
          end)
        ]]
      }).receive()
      SUB_PROCESS_ID = resp.Process
    ]=]
    )
  end)

  it("evaluates expressions inside subprocesses", function()
    local subProcessId = aolite.eval("proc", "return SUB_PROCESS_ID")
    assert.is_not_nil(subProcessId)

    aolite.send({
      From = "proc",
      Target = "proc",
      Action = "Eval",
      Data = [[
        local replyMsg = ao.send({
          Target = SUB_PROCESS_ID,
          Action = "Eval",
          Data = "if ao.id == '" .. SUB_PROCESS_ID .. "' then ao.send({ Target = 'proc', Action = 'Eval-Success', ['Update-Id'] = 'check-id' }) end"
        }).receive()

        local assignMsgId = assert(replyMsg.Tags["Msg-Id"], "Missing 'Msg-Id' in Eval-Msg-Id")
        print("assignMsgId", assignMsgId)
        Receive(function(message)
          local isFromChild = message.From == SUB_PROCESS_ID
          local isEvalSuccess = message.Action == "Eval-Success"
          local hasUpdateId = message.Tags["Update-Id"] == 'check-id'

          return isFromChild and isEvalSuccess and hasUpdateId
        end)

        ao.send({ Target = 'proc', Action = 'Test-Success' })
      ]],
    })

    local lastMsg = aolite.getLastMsg("proc")
    assert.are.equal("Test-Success", lastMsg.Action)
  end)
end)
