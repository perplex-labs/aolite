local compat_require = require -- dualRequire from aolite.compat

--
-- Returns a fresh copy of the upstream Handlers module, executed in its own
-- environment so that each AO process keeps an isolated handler list.
--
return function(processId)
  --
  -- Build a sandbox environment that inherits from _G but shadows its own
  -- global namespace.  The environment is kept minimal: only what the
  -- upstream file expects to find is pre-populated.
  --
  local env = {
    processId = processId,
    _VERSION = _VERSION,
  }
  env._G = env
  env._ENV = env

  -- Ensure standard libraries are visible through the metatable.
  setmetatable(env, { __index = _G })

  -- Provide a package table so that nested require() calls share the same
  -- loaded-module cache within this environment (but still fall back to the
  -- global cache for common libs).
  env.package = {
    loaded = {},
    searchers = package.searchers,
    path = package.path,
    cpath = package.cpath,
    config = package.config,
  }

  -- Environment-local require that first checks env.package.loaded, then
  -- delegates to the compat layer with this env so every nested require is
  -- executed inside the same sandbox.
  env.require = function(mod)
    local loaded = env.package.loaded
    if loaded[mod] then
      return loaded[mod]
    end

    -- 1) try compat dual require with sandbox
    local ok, res = pcall(compat_require, mod, env)
    if ok then
      loaded[mod] = res
      return res
    end

    -- 2) fall back to regular global require (for built-ins like 'coroutine')
    local ok2, res2 = pcall(require, mod)
    if ok2 then
      loaded[mod] = res2
      return res2
    end

    error(
      "handlers factory: cannot load module '"
        .. mod
        .. "'\ncompat error: "
        .. tostring(res)
        .. "\nglobal error: "
        .. tostring(res2)
    )
  end

  -- Kick-off: execute upstream implementation inside the sandbox
  local handlers = env.require("aos.process.handlers")

  -- Expose the result inside the env for modules that check the global name
  env.Handlers = handlers
  env.package.loaded[".handlers"] = handlers
  env.package.loaded["handlers"] = handlers

  return handlers
end
