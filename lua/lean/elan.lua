local subprocess_check_output = require('lean._util').subprocess_check_output
local elan = { toolchain = {} }

---Elan's dumped state, which can partially change from project to project.
---@class ElanState
---@field elan_version ElanVersionInfo
---@field toolchains ElanToolchainInfo

---@class ElanVersionInfo
---@field current string elan's own version
---@field newest table

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

--List the installed toolchains.
function elan.toolchain.list()
  local state = elan.state()
  return vim
    .iter(state.toolchains.installed)
    :map(function(each)
      return each.resolved_name
    end)
    :totable()
end

---Dump elan's state.
---@return ElanState
function elan.state()
  local stdout = subprocess_check_output { 'elan', 'dump-state' }
  return vim.json.decode(stdout)
end

return elan
