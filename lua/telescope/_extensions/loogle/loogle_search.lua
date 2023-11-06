local pickers = require('telescope.pickers')
local actions_state = require 'telescope.actions.state'
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local previewers = require('telescope.previewers')

local curl = require 'plenary.curl'

local M = {}


--- Ask for a type pattern in the UI
--- @return string?, string? type The first value is a type. The second a potential error.
M.ask_for_type = function()
  local type = ''
  local on_confirm = function(input) type = input end
  vim.ui.input({prompt = 'Enter Loogle type pattern: '}, on_confirm)
  if type == nil or type == '' then
    return nil, 'Type was empty'
  end
  return type, nil
end

--- Ask for a type pattern in the UI
--- @param type string The type pattern to look for.
--- @return table?, string? hits The first value is the hits in the Loogle JSON API format. The second a potential error
M.look_for_type = function(type)
  local res = curl.get {
    url = 'https://loogle.lean-lang.org/json',
    query = { q = type },
    headers = {
     ['User-Agent'] = 'lean.nvim'
    },
    accept = 'application/json',
  }

  if res.status ~= 200 then
    return nil, 'Loogle returned status code: ' .. res.status
  end

  local body = vim.fn.json_decode(res.body)
  if body.error then
    return nil, 'Loogle returned error: ' .. body.error
  end

  if body.count == 0 then
    return nil, 'Loogle found no matches'
  end

  return body.hits, nil
end

--- Use telescope to provide a Loogle API based type search
--- @param telescope_opts table Options for the telescope framework
M.find = function(telescope_opts)
  telescope_opts = vim.tbl_extend('keep', telescope_opts or {}, {})

  local type, results, err

  type, err = M.ask_for_type()
  if err then
    print(err)
    return
  end

  results, err = M.look_for_type(type)
  if err then
    print(err)
    return
  end

  pickers.new(telescope_opts, {
    prompt_title = 'Loogle Search Filter',
    finder = finders.new_table {
      results = results,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name
        }
      end
    },
    sorter = conf.generic_sorter(telescope_opts),
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local d = entry.value

        local output = { 'import ' .. d.module}
        table.insert(output, '')

        table.insert(output, d.name .. ' : ' .. d.type)

        require('telescope.previewers.utils').highlighter(self.state.bufnr, 'lean')
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, output)
      end
    }),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = actions_state.get_selected_entry()
        vim.api.nvim_put({ selection.value.name }, '', false, true)
      end)
      return true
    end,
  }):find()

end
return M
