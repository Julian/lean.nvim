local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local config = require('telescope.config')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')

local loogle = require('lean.loogle')

local M = {}

---@class LoogleTelescopeEntry
---@field value LoogleResult

--- Use telescope to provide a Loogle API based type search
--- @param telescope_opts table Options for the telescope framework
M.find = function(telescope_opts)
  telescope_opts = vim.tbl_extend('keep', telescope_opts or {}, {})

  local type
  vim.ui.input(
    { prompt = 'Enter a type pattern to search on Loogle: ' },
    function(choice) type = choice end
  )
  if not type or type == '' then return end

  local results, err = loogle.search(type)
  if err then
    vim.notify(('Loogle error: %s'):format(err), vim.log.levels.ERROR, {})
    return
  elseif vim.tbl_isempty(results or {}) then
    vim.notify(('No Loogle results for %q'):format(type), vim.log.levels.ERROR, {})
    return
  end

  pickers.new(telescope_opts, {
    prompt_title = 'Loogle Search Filter',
    finder = finders.new_table{
      results = results,
      ---@param entry LoogleResult
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name
        }
      end
    },
    sorter = config.values.generic_sorter(telescope_opts),

    previewer = previewers.new_buffer_previewer{
      ---@param entry LoogleTelescopeEntry
      define_preview = function(self, entry)
        local bufnr = self.state.bufnr
        local lines = loogle.template(entry.value)
        require('telescope.previewers.utils').highlighter(bufnr, 'lean')
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      end
    },
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        ---@type LoogleTelescopeEntry
        local selection = actions_state.get_selected_entry()
        vim.api.nvim_put({ selection.value.name }, 'c', true, true)
      end)
      return true
    end,
  }):find()

end
return M
