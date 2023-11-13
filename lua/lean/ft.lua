local ft = {}
local _LEAN3_STANDARD_LIBRARY = '.*/[^/]*lean[%-]+3.+/lib/'

local options = {
  default = 'lean',
  nomodifiable = {
    '.*/src/lean/.*', -- Lean 4 standard library
    '.*/lib/lean/src/.*', -- Lean 4 legacy standard library
    '.*/lean_packages/.*', -- Lean 4 dependencies
    _LEAN3_STANDARD_LIBRARY .. '.*',
    '/_target/.*/.*.lean', -- Lean 3 dependencies
  },
}

options._DEFAULTS = vim.deepcopy(options)

local global_default_managed = false
function ft.enable(opts)
  if not global_default_managed and not lean_nvim_default_filetype then
    -- we are not managing the ft global, but it has no value.
    -- this means we have to manage it
    global_default_managed = true
  end
  options = vim.tbl_extend('force', options, opts)
  if global_default_managed then
    lean_nvim_default_filetype = options.default
  end
end

---Make the given buffer `nomodifiable` if its file name matches a configured list.
function ft.__maybe_make_nomodifiable(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  for _, pattern in ipairs(options.nomodifiable) do
    if name:match(pattern) then
      vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
      return
    end
  end
end

return ft
