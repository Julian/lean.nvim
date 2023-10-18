local if_has_lean3 = require('tests.helpers').if_has_lean3

if_has_lean3('checkhealth', function()
  it('passes the health check', function()
    vim.api.nvim_command('silent checkhealth lean3')
    assert.has_match([[
.*lean3:.*
.*- .*OK.* `lean--language--server`
]], table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'))
  end)
end)
