package = "aolite"
version = "0.2.0-1"
source = {
   url = "git://github.com/perplex-labs/aolite",
   tag = "v0.2.0"
}
description = {
   summary = "A local, concurrent emulation of the AO protocol for testing Lua processes.",
   detailed = [[
      Provides a simulated Arweave AO environment (aolite) for developers to test
      their AO processes and interactions locally. Includes support for message passing,
      process spawning, scheduling, and process evals.
   ]],
   homepage = "https://github.com/perplex-labs/aolite",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      aolite = "lua/aolite/main.lua",
      ["aolite.api"] = "lua/aolite/api.lua",
      ["aolite.env"] = "lua/aolite/env.lua",
      ["aolite.eval_exp"] = "lua/aolite/eval_exp.lua",
      ["aolite.process"] = "lua/aolite/process.lua",
      ["aolite.scheduler"] = "lua/aolite/scheduler.lua",
      ["aolite.compat"] = "lua/aolite/compat.lua",

      ["aolite.ao.ao"] = "lua/aolite/ao/ao.lua",
      ["aolite.ao.assignment"] = "lua/aolite/ao/assignment.lua",
      ["aolite.ao.boot"] = "lua/aolite/ao/boot.lua",
      ["aolite.ao.default"] = "lua/aolite/ao/default.lua",
      ["aolite.ao.handlers"] = "lua/aolite/ao/handlers.lua",
      ["aolite.ao.handlers-utils"] = "lua/aolite/ao/handlers-utils.lua",
      ["aolite.ao.process"] = "lua/aolite/ao/process.lua",

      ["aolite.lib.bint"] = "lua/aolite/lib/bint.lua",
      ["aolite.lib.json"] = "lua/aolite/lib/json.lua",
      ["aolite.lib.log"] = "lua/aolite/lib/log.lua",
      ["aolite.lib.serialize"] = "lua/aolite/lib/serialize.lua",
      ["aolite.lib.utils"] = "lua/aolite/lib/utils.lua",
      ["aolite.lib.crypto"] = "lua/aolite/lib/crypto/init.lua"
   }
}