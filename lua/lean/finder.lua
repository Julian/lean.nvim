---@brief [[
--- Grep-like searching across specified Lean directories.
---
--- Supports either `telescope.nvim` or `denite.nvim` as the underlying
--- implementation.
---@brief ]]

---@tag lean.finder

local finder = {}
local options = { _DEFAULTS = { implementation = "telescope", paths = { "." } } }

local function telescope_start(paths)
  require'telescope.builtin'.live_grep{ search_dirs = paths }
end

local function denite_start(paths)
  vim.fn['denite#start'](
    vim.tbl_map(function(path)
      return { name = "grep", args = { path, "", "!"} }
    end, paths)
  )
end

local implementations = { telescope = telescope_start, denite = denite_start }

function finder.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
end

--- Start finding something within the configured paths.
function finder.start()
  implementations[options.implementation](options.paths)
end

return finder
