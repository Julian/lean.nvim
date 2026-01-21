---@brief [[
--- Tests for code actions.
---@brief ]]

local helpers = require 'spec.helpers'

require('lean').setup {}

describe('code actions', function()
  it(
    'for unknown identifiers add missing imports',
    helpers.clean_buffer('#check codeaction', function()
      local client = helpers.wait_for_ready_lsp()

      helpers.search 'code'
      assert.infoview_contents.are [[
        ▼ 1:8-1:18: error:
        Unknown identifier `codeaction`

        Error code: lean.unknownIdentifier
        View explanation
      ]]

      ---@type lsp.CodeActionParams
      local params = vim.tbl_extend(
        'error',
        vim.lsp.util.make_range_params(0, 'utf-16'),
        { context = { diagnostics = {} } } ---@type lsp.CodeActionContext
      )

      local response = client:request_sync('textDocument/codeAction', params, 10000)
      assert.is_not_nil(response and response.result)

      local edit = vim.iter(response.result):next().edit
      vim.lsp.util.apply_workspace_edit(edit, 'utf-16')

      -- it seems non-deterministic whether this is Lean.Lsp.CodeActions
      -- or Lean.command_code_actions... so just match on `Lean.`

      assert.matches('Lean.', vim.api.nvim_get_current_line())
    end)
  )
end)
