local scheduler = {}

function scheduler.run(env)
  local maxCycles = 100
  local cycles = 0

  while cycles < maxCycles do
    local didWork = false

    -- copy the current ready set
    local readyList = {}
    for pid, _ in pairs(env.ready) do
      table.insert(readyList, pid)
    end
    -- reset ready so fresh messages re-mark themselves
    env.ready = {}

    for _, procId in ipairs(readyList) do
      local co = env.coroutines[procId]
      if co and coroutine.status(co) == "suspended" then
        local ok, err = coroutine.resume(co)
        if not ok then
          error("Error in process " .. procId .. ": " .. tostring(err))
        end
        didWork = true
      end
    end

    if not didWork then
      break
    end
    cycles = cycles + 1
  end
end

return scheduler
