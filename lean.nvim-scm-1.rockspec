local MODREV, SPECREV = 'scm', '-1'
rockspec_format = '3.0'

package = 'lean.nvim'
version = MODREV .. SPECREV

description = {
  summary = 'Neovim support for the Lean theorem prover',
  detailed = 'Interactive theorem proving inside Neovim.',
  labels = { 'neovim', 'plugin', 'lean', 'leanprover' },
  homepage = 'https://github.com/Julian/lean.nvim',
  license = 'MIT',
}

dependencies = {
  'plenary.nvim',
}

source = {
  url = 'https://github.com/Julian/lean.nvim',
}

build = {
  type = 'builtin',
}
