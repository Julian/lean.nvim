local project = require('spec.fixtures').project
local helpers = require 'spec.helpers'

require('lean').setup {}

describe('ft.detect', function()
  for kind, path in project:files() do
    it('detects ' .. kind .. ' lean files', function()
      vim.cmd.edit { path, bang = true }
      assert.are.equal('lean', vim.bo.filetype)
    end)
  end

  it('detects standard library files', function()
    vim.cmd.edit { project.child 'Example/JumpToStdlib.lean', bang = true }
    assert.are.equal('lean', vim.bo.filetype)
    local initial_path = vim.api.nvim_buf_get_name(0)

    vim.cmd.normal 'G$'
    helpers.wait:for_ready_infoview()
    local client = helpers.wait:for_ileans()

    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    local result = client:request_sync('textDocument/definition', params, 30000)
    assert.message('go-to-definition request failed').is_truthy(result and result.result)
    local locations = vim.islist(result.result) and result.result or { result.result }
    assert.message('no definition locations returned').is_truthy(#locations > 0)
    local uri = locations[1].uri or locations[1].targetUri
    local bufnr = vim.fn.bufadd(vim.uri_to_fname(uri))
    vim.bo[bufnr].buflisted = true
    vim.api.nvim_win_set_buf(0, bufnr)

    assert
      .message('definition did not jump to a different file')
      .is_truthy(vim.api.nvim_buf_get_name(0) ~= initial_path)

    helpers.wait_for_filetype()
    assert.are.equal('lean', vim.bo.filetype)
  end)

  it('marks standard library files nomodifiable by default', function()
    local name = vim.api.nvim_buf_get_name(0)
    local is_core = name:match '.*/src/lean/.*' or name:match '.*/lib/lean/src/.*'
    assert.message("Didn't jump to core Lean!").is_truthy(is_core)
    assert.is_falsy(vim.bo.modifiable)
  end)

  it('marks dependency files nomodifable by default', function()
    vim.cmd.edit { project.some_dependency_file, bang = true }
    assert.is_falsy(vim.bo.modifiable)
  end)

  it('does not mark other lean files nomodifiable', function()
    vim.cmd.edit { project.some_existing_file, bang = true }
    assert.is_truthy(vim.bo.modifiable)
  end)
end)
