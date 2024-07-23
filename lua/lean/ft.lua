local ft = {}

local options = {
  default = 'lean',
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
  for _, pattern in ipairs(options.nomodifiable) do
    if name:match(pattern) then
      vim.bo[bufnr].modifiable = false
      return
    end
  end
end

return ft
