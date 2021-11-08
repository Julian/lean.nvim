local ft = {}
local options = {
  default = "lean",
  _DEFAULTS = {
    default = "lean",
    make_deps_nomodifiable = true,
  }
}

local _LEAN3_STANDARD_LIBRARY = '.*/[^/]*lean[%-]+3.+/lib/'
local _LEAN3_VERSION_MARKER = '.*lean_version.*\".*:3.*'
local _LEAN4_VERSION_MARKER = '.*lean_version.*\".*lean4:.*'

local find_project_root = require('lspconfig.util').root_pattern(
  'leanpkg.toml',
  'lakefile.lean',
  'lean-toolchain'
)

function ft.detect(filename)
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

--- Maybe make the current buffer `nomodifiable` unless configured not to.
---
--- Prevents unintentional modification of files in `_target` (i.e. Lean
--- dependencies).
function ft.__maybe_make_nomodifiable(fname)
  if not options.make_deps_nomodifiable then return end
  if fname:find('/_target/.*/.*.lean') then vim.bo.modifiable = false end
end

function ft.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
end

return ft
