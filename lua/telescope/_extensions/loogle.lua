local actions = require 'telescope.actions'
local actions_state = require 'telescope.actions.state'
local config = require 'telescope.config'
local finders = require 'telescope.finders'
local pickers = require 'telescope.pickers'
local previewers = require 'telescope.previewers'

local loogle = require 'lean.loogle'

---@class LoogleTelescopeEntry
---@field value LoogleResult
---@field display string what to display in telescope for this result
---@field ordinal string how to sort this result in telescope

---Use telescope to provide a Loogle API based type search
---@param opts table Options for the telescope framework
local function telescope_loogle(opts)
  opts = vim.tbl_extend('keep', opts or {}, { debounce = 200 })

  pickers
    .new(opts, {
      prompt_title = 'Loogle',
      debounce = opts.debounce,
      finder = finders.new_dynamic {
        ---@param prompt string the currently entered telescope prompt
        fn = function(prompt)
          if not prompt or prompt == '' then
            return nil
          end

          local results, err = loogle.search(prompt)
          local should_fail_loudly = #prompt > 4
          if err and should_fail_loudly then
            vim.notify(err, vim.log.levels.ERROR, { title = 'Loogle Error' })
            return {}
          elseif vim.tbl_isempty(results or {}) and should_fail_loudly then
            vim.notify('No Loogle results.', vim.log.levels.INFO)
            return {}
          end
          return results
        end,
        ---@param entry LoogleResult
        ---@return LoogleTelescopeEntry
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name,
            ordinal = entry.name,
          }
        end,
      },
      sorter = config.values.generic_sorter(opts),

      previewer = previewers.new_buffer_previewer {
        ---@param entry LoogleTelescopeEntry
        define_preview = function(self, entry)
          local bufnr = self.state.bufnr
          local lines = loogle.template(entry.value)
          require('telescope.previewers.utils').highlighter(bufnr, 'lean')
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end,
      },
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          ---@type LoogleTelescopeEntry
          local selection = actions_state.get_selected_entry()
          if selection then
            vim.api.nvim_put({ selection.value.name }, 'c', true, true)
          end
        end)
        return true
      end,
    })
    :find()
end

return require('telescope').register_extension {
  exports = {
    loogle = telescope_loogle,
  },
}
