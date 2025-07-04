return {
  handle = function(msg, env)
    for _, tag in ipairs(msg.Tags) do
      if tag.name == "Action" and tag.value == "Spawn" then
        env.ao.spawn("spec.modules.module_spawn", {})
      end
    end
    return env.ao.outbox
  end,
}
