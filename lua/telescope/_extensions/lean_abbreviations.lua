local actions = require 'telescope.actions'
local actions_state = require 'telescope.actions.state'
local config = require 'telescope.config'
local finders = require 'telescope.finders'
local pickers = require 'telescope.pickers'
local previewers = require 'telescope.previewers'

local abbreviations = require 'lean.abbreviations'

---@class AbbreviationTelescopeEntry
---@field value string
---@field display string what to display in telescope for this result
---@field replacement string the expanded abbreviation
---@field ordinal string how to sort this result in telescope

---Use telescope to list or expand Lean unicode abbreviations.
---@param opts table Options for the telescope framework
local function telescope_abbreviations(opts)
  pickers
    .new(opts, {
      prompt_title = 'Lean Unicode Abbreviations',
      finder = finders.new_table {
        results = vim.iter(abbreviations.load()):totable(),
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry[1],
            replacement = entry[2],
            ordinal = entry[1],
          }
        end,
      },
      sorter = config.values.generic_sorter(opts),

      previewer = previewers.new_buffer_previewer {
        ---@param entry AbbreviationTelescopeEntry
        define_preview = function(self, entry)
          local bufnr = self.state.bufnr
          require('telescope.previewers.utils').highlighter(bufnr, 'lean')
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { entry.replacement })
        end,
      },
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          ---@type AbbreviationTelescopeEntry
          local selection = actions_state.get_selected_entry()
          if selection then
            vim.api.nvim_put({ selection.replacement }, 'c', true, true)
          end
        end)
        return true
      end,
    })
    :find()
end

return require('telescope').register_extension {
  exports = {
    lean_abbreviations = telescope_abbreviations,
  },
}
