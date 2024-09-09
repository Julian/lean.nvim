local ft = {}

local options = {
  nomodifiable = {
    '.*/src/lean/.*', -- Lean core
  },
}

options._DEFAULTS = vim.deepcopy(options)

function ft.enable(opts)
  options = vim.tbl_extend('force', options, opts)
end

---Make the given buffer `nomodifiable` if its file name matches a configured list.
function ft.__maybe_make_nomodifiable(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  vim.bo[bufnr].modifiable = vim.iter(options.nomodifiable):any(function(pattern)
    return not name:match(pattern)
  end)
end

return ft
