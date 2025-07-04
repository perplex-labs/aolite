local reference = 0
local process = { _version = "0.0.1" }

function process.handle(msg, _)
  -- Build a minimal outbox echoing the received data back to the sender
  local outbox = {
    Assignments = {},
    Messages = {},
    Spawns = {},
    Output = "echoed message " .. msg.Id .. " back to " .. msg.From,
  }

  local reply = {
    Target = msg.From,
    Data = msg.Data,
    Anchor = string.format("%032d", reference),
    Tags = {
      { name = "Reference", value = tostring(reference) },
    },
  }

  -- Bubble the Action tag through if it exists so the test can match on it
  for _, tag in ipairs(msg.Tags or {}) do
    if tag.name == "Action" then
      table.insert(reply.Tags, { name = "Action", value = tag.value })
    end
  end

  table.insert(outbox.Messages, reply)
  reference = reference + 1
  return outbox
end

return process
