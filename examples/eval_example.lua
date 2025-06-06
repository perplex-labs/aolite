local ao = require("aolite")

-- Spawn an empty process from the process template file
-- Note the path uses dot notation and omits the .lua extension
local procId = "evalproc"
ao.spawnProcess(procId, "examples.process_template")

-- Evaluate arbitrary code inside the process
local result = ao.eval(procId, "return 2 + 3")
print("Eval result:", result)
