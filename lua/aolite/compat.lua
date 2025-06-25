local originalRequire = require

-- This function handles the path mapping for both require and loadfile.
local function resolveModulePath(moduleName)
  -- Mapping of module names to paths
  local moduleMap = {
    ["env"] = "aolite.env",
    [".log"] = "aolite.lib.log",
    [".serialize"] = "aolite.lib.serialize",
    [".json"] = "aolite.lib.json",
    ["json"] = "aolite.lib.json",

    -- ao factory wrappers
    -- ["process"] = "aos.process.process",
    [".process"] = "aolite.factories.process",
    ["ao"] = "aolite.factories.ao",
    [".ao"] = "aolite.factories.ao",
    [".handlers"] = "aolite.factories.handlers",
    -- ao namespace, aliased
    [".boot"] = "aos.process.boot",
    [".default"] = "aos.process.default",
    [".assignment"] = "aos.process.assignment",
    [".eval"] = "aos.process.eval",
    [".handlers-utils"] = "aos.process.handlers-utils",
    -- ["handlers"] = "aos.process.handlers",
    [".base64"] = "aos.process.base64",
    [".chance"] = "aos.process.chance",
    [".pretty"] = "aos.process.pretty",
    [".dump"] = "aos.process.dump",
    [".stringify"] = "aos.process.stringify",
    [".apm"] = "aos.process.apm",
    [".bint"] = "aos.process.bint",
    [".utils"] = "aos.process.utils",

    -- other standard mappings
    ["bit"] = "bit32", -- Mapping to bit32 library
  }

  -- Handle specific mappings
  if moduleMap[moduleName] then
    return moduleMap[moduleName]
  end

  -- Handle all ".crypto" submodules dynamically
  -- e.g., require(".crypto.public") becomes require("aolite.lib.crypto.public")
  if moduleName:match("^%.crypto") then
    return moduleName:gsub("^%.crypto", "aos.process.crypto", 1)
  end

  -- If no specific match, return the module name itself for standard Lua resolution
  return moduleName
end

local function loadfileRequire(moduleName, processEnv)
  local resolvedPath = resolveModulePath(moduleName)
  local filePath = resolvedPath:gsub("%.", "/")

  local searchPath = package.searchpath(filePath, package.path)
  if searchPath then
    -- Open and read the file
    local file, err_open = io.open(searchPath, "r")
    if not file then
      error(
        "Failed to open file: "
          .. searchPath
          .. " ("
          .. (err_open or "unknown error")
          .. ") for module "
          .. moduleName
          .. " (resolved to "
          .. resolvedPath
          .. ")"
      )
    end
    local contents, err_read = file:read("*a")
    file:close()
    if not contents and err_read then
      error("Failed to read file contents: " .. searchPath .. " (" .. err_read .. ")")
    end

    -- Now load the chunk from the string, with the provided processEnv
    local chunk, err_load = load(contents, "@" .. searchPath, "bt", processEnv)
    if not chunk then
      error(
        "Failed to load chunk from "
          .. searchPath
          .. " for module "
          .. moduleName
          .. " (resolved to "
          .. resolvedPath
          .. "): "
          .. (err_load or "unknown error")
      )
    end

    return chunk()
  else
    error(
      "Module '"
        .. moduleName
        .. "' (resolved to '"
        .. resolvedPath
        .. "') not found in package.path using loadfile approach."
    )
  end
end

local function mockedRequire(moduleName)
  -- Use the resolved path for the original require
  local resolvedPath = resolveModulePath(moduleName)
  return originalRequire(resolvedPath)
end

local function dualRequire(moduleName, processEnv)
  if processEnv then
    -- Use loadfile when the second argument (processEnv) is provided
    return loadfileRequire(moduleName, processEnv)
  else
    -- Fall back to the default require behavior, but with resolved path
    return mockedRequire(moduleName)
  end
end

return function()
  -- Override the require function globally
  _G.require = dualRequire
  -- Set global verbosity flag if needed by downstream projects
  _G.PrintVerb = tonumber(os.getenv("AOLITE_PRINT_VERB"))
end
