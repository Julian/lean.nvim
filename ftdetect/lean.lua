local _LEAN3_STANDARD_LIBRARY = '.*/[^/]*lean[%-]+3.+/lib/'
local _LEAN3_VERSION_MARKER = '.*lean_version.*".*:3.*'
local _LEAN4_VERSION_MARKER = '.*lean_version.*".*lean4:.*'

local function detect(filename)
  if filename:match '^fugitive://.*' then
    filename = pcall(vim.fn.FugitiveReal, filename)
  end

  local abspath = vim.fn.fnamemodify(filename, ':p')
  local filetype = lean_nvim_default_filetype
  if not filetype then
    filetype = 'lean'
  end

  if abspath:match(_LEAN3_STANDARD_LIBRARY) then
    filetype = 'lean3'
  else
    local find_project_root =
      require('lspconfig.util').root_pattern('leanpkg.toml', 'lakefile.lean', 'lean-toolchain')
    local project_root = find_project_root(abspath)
    local succeeded, result
    if project_root then
      succeeded, result = pcall(vim.fn.readfile, project_root .. '/lean-toolchain')
      if succeeded then
        if result[1]:match '.*:3.*' then
          filetype = 'lean3'
        elseif result[1]:match '.*lean4:.*' then
          filetype = 'lean'
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

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.lean',
  callback = function(opts)
    detect(opts.file)
  end,
})
