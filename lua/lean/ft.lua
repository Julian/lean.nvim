local ft = {}

lean_nvim_ft_options._DEFAULTS = vim.deepcopy(lean_nvim_ft_options)

function ft.enable(opts)
  lean_nvim_ft_options= vim.tbl_extend("force", lean_nvim_ft_options._DEFAULTS, opts)
end

---Make the given buffer `nomodifiable` if its file name matches a configured list.
function ft.__maybe_make_nomodifiable(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  for _, pattern in ipairs(lean_nvim_ft_options.nomodifiable) do
    if name:match(pattern) then
      vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
      return
    end
  end
end

return ft
