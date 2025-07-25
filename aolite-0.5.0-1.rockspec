rockspec_format = "3.0"
package = "aolite"
version = "0.5.0-1"
source = {
   url = "git://github.com/perplex-labs/aolite",
   tag = "v0.5.0"
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
   "lua == 5.3"
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

      ["aolite.lib.json"] = "lua/aolite/lib/json.lua",
      ["aolite.lib.log"] = "lua/aolite/lib/log.lua",
      ["aolite.lib.serialize"] = "lua/aolite/lib/serialize.lua",
      
      ["aos.process.boot"] = "lua/aos/process/boot.lua",
      ["aos.process.default"] = "lua/aos/process/default.lua",
      ["aos.process.assignment"] = "lua/aos/process/assignment.lua",
      ["aos.process.eval"] = "lua/aos/process/eval.lua",
      ["aos.process.handlers-utils"] = "lua/aos/process/handlers.lua",
      ["aos.process.handlers"] = "lua/aos/process/handlers.lua",
      ["aos.process.base64"] = "lua/aos/process/base64.lua",
      ["aos.process.chance"] = "lua/aos/process/chance.lua",
      ["aos.process.pretty"] = "lua/aos/process/pretty.lua",
      ["aos.process.dump"] = "lua/aos/process/dump.lua",
      ["aos.process.stringify"] = "lua/aos/process/stringify.lua",
      ["aos.process.apm"] = "lua/aos/process/apm.lua",
      ["aos.process.bint"] = "lua/aos/process/bint.lua",
      ["aos.process.utils"] = "lua/aos/process/utils.lua",
   },
}