local compat_require = require -- dualRequire from aolite.compat

-- Build a fresh upstream AO instance executed inside a per-process sandbox
return function(Handlers)
  assert(type(Handlers) == "table", "Handlers table expected")

  ---------------------------------------------------------------------------
  -- 1.  Create the sandbox environment that the upstream file will run in --
  ---------------------------------------------------------------------------
  local env = {}
  env._G = env
  env._ENV = env

  -- pre-populate globals expected by upstream code
  env.Handlers = Handlers

  -- Minimal package table so that nested require() calls share the same cache
  env.package = {
    loaded = {
      ["Handlers"] = Handlers,
      [".handlers"] = Handlers,
    },
    searchers = package.searchers,
    path = package.path,
    cpath = package.cpath,
    config = package.config,
  }

  -- Sandbox-local require: first consult env.package.loaded then delegate to
  -- compat_require (which will execute the module inside this env).
  env.require = function(mod)
    local loaded = env.package.loaded
    if loaded[mod] then
      return loaded[mod]
    end
    local ok, res = pcall(compat_require, mod, env)
    if ok then
      loaded[mod] = res
      return res
    end
    -- fall back to host require for Lua libs
    local ok2, res2 = pcall(require, mod)
    if ok2 then
      loaded[mod] = res2
      return res2
    end
    error(res)
  end

  -- allow fallback to standard libs
  setmetatable(env, { __index = _G })

  ---------------------------------------------------------------------------
  -- 2.  Execute the upstream AO implementation in this environment          --
  ---------------------------------------------------------------------------
  local ao = compat_require("aos.process.ao", env) -- new independent copy

  -- Expose the table in env for any module doing `ao = require('.ao')`
  env.ao = ao
  env.package.loaded[".ao"] = ao
  env.package.loaded["ao"] = ao

  ---------------------------------------------------------------------------
  -- 3.  Initialise assignment helpers (upstream pattern)                    --
  ---------------------------------------------------------------------------
  local assignment = env.require(".assignment")
  assignment.init(ao)

  return ao
end
