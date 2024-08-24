local async = require 'plenary.async'

local rpc = require 'lean.rpc'

local edit = {
  declaration = {},
}
edit.decl = edit.declaration

function edit.declaration.goto_start(window, sess)
  window = window or 0
  local params = vim.lsp.util.make_position_params(window)
  sess = sess or rpc.open(params)

  async.void(function()
    local result = sess:declarationRangeAt(params)
    if not result then
      return
    end

    local line = result.start.line + 1
    local character = result.start.character

    local current = vim.api.nvim_win_get_cursor(window)
    if line == current[1] and character == current[2] then
      vim.print 'SEARCH BACKWARDS INSTEAD'
      return
    end

    vim.api.nvim_win_set_cursor(window, { line, character })
  end)()
end

function edit.declaration.goto_end(window, sess)
  window = window or 0
  local params = vim.lsp.util.make_position_params(window)
  sess = sess or rpc.open(params)

  async.void(function()
    local result = sess:declarationRangeAt(params)
    if not result then
      return
    end
    vim.api.nvim_win_set_cursor(window, {
      result['end'].line + 1,
      result['end'].character,
    })
  end)()
end

return edit
