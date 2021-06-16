local treesitter = {}

function treesitter.enable(opts)
  local has_treesitter, parsers = pcall(require, 'nvim-treesitter.parsers')
  if not has_treesitter then return end

  opts.install_info = opts.install_info or {
    url = 'https://github.com/Julian/tree-sitter-lean',
    files = {"src/parser.c", "src/scanner.cc"},
    branch = 'main',
  }
  opts.filetype = opts.filetype or 'lean'
  parsers.get_parser_configs().lean = opts
end

return treesitter
