---@toc elan

---@mod elan.init Introduction

---@brief [[
--- Interaction with Lean's version manager, elan.
---
--- See :help lean for information on lean.nvim.
---@brief ]]

---@tag elan.nvim

local check_output = require('std.subprocess').check_output

local elan = {}

---Elan's dumped state, which can partially change from project to project.
---@class ElanState
---@field elan_version ElanVersionInfo
---@field toolchains ElanToolchainInfo

---@class ElanVersionInfo
---@field current string elan's own version
---@field newest table

---Dump elan's state.
---@return ElanState
function elan.state()
  local stdout = check_output { 'elan', 'dump-state' }
  return vim.json.decode(stdout)
end

return elan
