---@brief [[
--- A satellite.nvim progress handler.
---
--- See https://github.com/lewis6991/satellite.nvim/blob/main/HANDLERS.md
---@brief ]]

local async = require 'satellite.async'
local row_to_barpos = require('satellite.util').row_to_barpos

local progress = require 'lean.progress'

local SYMBOL = '│'
local HIGHLIGHT = 'leanProgressBar'

--- @type Satellite.Handler
local handler = {
  name = 'lean.nvim',
}

--- @class Lean.SatelliteConfig: Satellite.Handlers.BaseConfig
local config = {
  enable = true,
  overlap = true,
  priority = 20, -- cursor looks like 100
}

local function setup_hl()
  vim.api.nvim_set_hl(0, HIGHLIGHT, {
    default = true,
    fg = vim.api.nvim_get_hl(0, { name = 'NonText' }).fg,
  })
end

--- @param user_config Satellite.Handlers.CursorConfig
--- @param update fun()
function handler.setup(user_config, update)
  config = vim.tbl_deep_extend('force', config, user_config)
  handler.config = config

  local group = vim.api.nvim_create_augroup('LeanSatellite', {})

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = setup_hl,
  })

  setup_hl()

  vim.api.nvim_create_autocmd('User', {
    pattern = progress.AUTOCMD,
    group = group,
    callback = update,
  })
end

function handler.update(bufnr, winid)
  local marks = {} --- @type Satellite.Mark[]

  local infos = progress.proc_infos[vim.uri_from_bufnr(bufnr)] or {}
  local pred = async.winbuf_pred(bufnr, winid)

  for _, info in async.ipairs(infos or {}, pred) do
    local min_lnum = math.max(1, info.range.start.line)
    local min_pos = row_to_barpos(winid, min_lnum - 1)

    local max_lnum = math.max(1, info.range['end'].line + math.max(0, info.range.start.line - 1))
    local max_pos = row_to_barpos(winid, max_lnum - 1)

    for pos = min_pos, max_pos do
      marks[#marks + 1] = {
        pos = pos,
        symbol = SYMBOL,
        highlight = HIGHLIGHT,
      }
    end
  end

  return marks
end

return handler
