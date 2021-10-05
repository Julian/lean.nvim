local log = require'vim.lsp.log'
local stderr = {}

-- Show stderr output in :messages
-- TODO: add upstream neovim API
function stderr.enable()
  local old_error = log.error
  log.error = function(...)
    local argc = select('#', ...)
    if argc == 0 then return true end -- always enable error messages
    if argc == 4 and select(1, ...) == 'rpc' and select(3, ...) == 'stderr'
        and string.match(select(2, ...), 'lean') then
      local chunk = select(4, ...)
      vim.schedule(function() vim.api.nvim_err_writeln(chunk) end)
    end
    old_error(...)
  end
end

return stderr
