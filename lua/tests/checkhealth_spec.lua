require('tests.helpers')

describe('checkhealth', function()
  it('passes the health check', function()
    vim.cmd('silent checkhealth lean')
    assert.has_match([[
.*lean.nvim.*
.*- .*OK.* `lean ----version`
.*-.* Lean .*version .+
]], table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'))
  end)
end)
