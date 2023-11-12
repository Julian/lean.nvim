return {
  --- Check whether Lean 3 support is healthy.
  ---
  --- Call me via `:checkhealth lean3`.
  check = function()
    vim.health.start 'lean3'
    if require('lean.lean3').works() then
      vim.health.ok '`lean-language-server`'
    else
      vim.health.warn '`lean-language-server` not found, lean 3 support will not work'
    end
  end,
}
