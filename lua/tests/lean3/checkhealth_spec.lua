require('tests.helpers')

describe('checkhealth', function()
  it('passes the health check', function()
    vim.api.nvim_command('silent checkhealth lean3')
    assert.has_match([[
.*lean3:.*
.*- .*OK.* `lean--language--server`
]], table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'))
  end)
end)
