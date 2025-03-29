local check_output = require('std.subprocess').check_output

local elan = require 'elan'
local toolchain = {}

---Information about installed and active Lean toolchains.
---@class ElanToolchainInfo
---@field active_override? table information about an overridden toolchain for the current project
---@field default? table information about the default toolchain
---@field installed ElanToolchain[] the currently installed toolchains
---@field resolved_active table information about the resolved active toolchain

---A single toolchain.
---@class ElanToolchain
---@field path string the path to the toolchain on this machine
---@field resolved_name string the identifier for this toolchain

---Information about a toolchain which is in use by a project on the machine.
---@class ElanUsedToolchain
---@field toolchain string the name of the toolchain
---@field user string a path (or in some cases reason) that causes the toolchain to be considered in-use

---Determine which toolchains are in use.
---@return string[] unused the unused toolchains currently installed
---@return ElanUsedToolchain[] used any used toolchains

function toolchain.gc()
  local stdout = check_output { 'elan', 'toolchain', 'gc', '--json' }
  local result = vim.json.decode(stdout)
  return result.unused_toolchains, result.used_toolchains
end

---List the installed toolchains.
---@return string[] toolchains the toolchains
function toolchain.list()
  local state = elan.state()
  return vim
    .iter(state.toolchains.installed)
    ---@param each ElanToolchain
    :map(function(each)
      return each.resolved_name
    end)
    :totable()
end

return toolchain
