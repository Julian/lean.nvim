local ft = {}

local _LEAN3_STANDARD_LIBRARY = '.*/[^/]*lean[%-]+3.+/lib/'
local _LEAN3_VERSION_MARKER = '.*lean_version.*".*:3.*'
local _LEAN4_VERSION_MARKER = '.*lean_version.*".*lean4:.*'

local options = {
  default = "lean",
  nomodifiable = {
    '.*/src/lean/.*',       -- Lean 4 standard library
    '.*/lib/lean/src/.*',   -- Lean 4 legacy standard library
    '.*/lean_packages/.*',  -- Lean 4 dependencies
    _LEAN3_STANDARD_LIBRARY .. '.*',
    '/_target/.*/.*.lean'   -- Lean 3 dependencies
  }
}
options._DEFAULTS = vim.deepcopy(options)

local find_project_root = require('lspconfig.util').root_pattern(
  'leanpkg.toml',
  'lakefile.lean',
  'lean-toolchain'
)

function ft.detect(filename)
  if filename:match('^fugitive://.*') then
    filename = pcall(vim.fn.FugitiveReal, filename)
  end

  local abspath = vim.fn.fnamemodify(filename, ":p")
  local filetype = options.default
  if abspath:match(_LEAN3_STANDARD_LIBRARY) then
    filetype = 'lean3'
  else
    local project_root = find_project_root(abspath)
    local succeeded, result
    if project_root then
      succeeded, result = pcall(vim.fn.readfile, project_root .. '/lean-toolchain')
      if succeeded then
        if result[1]:match('.*:3.*') then filetype = 'lean3'
        elseif result[1]:match('.*lean4:.*') then filetype = 'lean'
        end
      else
        succeeded, result = pcall(vim.fn.readfile, project_root .. '/leanpkg.toml')
        if succeeded then
          for _, line in ipairs(result) do
            if line:match(_LEAN3_VERSION_MARKER) then
              filetype = 'lean3'
              break
            end
            if line:match(_LEAN4_VERSION_MARKER) then
              filetype = 'lean'
              break
            end
          end
        end
      end
    end
  end
  vim.opt.filetype = filetype
end

function ft.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
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
