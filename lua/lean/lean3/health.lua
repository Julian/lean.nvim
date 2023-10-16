local Job = require('plenary.job')

return {
  --- Check whether Lean 3 support is healthy.
  ---
  --- Call me via `:checkhealth lean3`.
  check = function()
    vim.health.start('lean3')
    local succeeded, lean3ls = pcall(Job.new, Job, {
      command = 'lean-language-server',
      args = { '--stdio' },
      writer = ''
    })
    if succeeded then
      lean3ls:sync()
      vim.health.ok('`lean-language-server`')
    else
      vim.health.warn('`lean-language-server` not found, lean 3 support will not work')
    end
  end
}
