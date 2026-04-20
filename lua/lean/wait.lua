local infoview = require 'lean.infoview'
local lsp = require 'lean.lsp'
local progress = require 'lean.progress'

local Wait = { timeout = 30000 }
Wait.__index = Wait

---Return a new Wait with a specific timeout.
---@param timeout_ms integer
function Wait:with_timeout(timeout_ms)
  return setmetatable({ timeout = timeout_ms }, { __index = self })
end

---@private
function Wait:_wait(label, condition)
  local ok = vim.wait(self.timeout, condition)
  if not ok then
    error(('%s did not complete within %dms'):format(label, self.timeout))
  end
end

---Wait for the LSP client to be ready for the current buffer.
---@return vim.lsp.Client
function Wait:for_lsp()
  local client
  self:_wait('LSP ready', function()
    client = lsp.client_for(0)
    return client and client.initialized or false
  end)
  return client
end

---Wait until the server finishes processing the cursor position.
---
---If the position is not yet being processed, waits for processing to
---begin first (up to the full timeout), then waits for it to finish.
function Wait:for_processing()
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  if progress.at(params) == nil then
    vim.wait(self.timeout, function()
      return progress.at(params) ~= nil
    end)
  end
  self:_wait('processing finished', function()
    return progress.at(params) == nil
  end)
end

---Wait until the server begins processing the current buffer.
function Wait:for_file_processing()
  self:_wait('file processing', function()
    return progress.percentage() < 100
  end)
end

---Wait for all pins in the infoview to finish loading.
---@param iv? Infoview
function Wait:for_ready_infoview(iv)
  iv = iv or infoview.get_current_infoview()
  if not iv then
    error 'Infoview is not open!'
  end
  iv:wait(self.timeout)
end

---Wait for the infoview to contain the given pattern.
---@param pattern string a Lua pattern to match against the infoview contents
---@param iv? Infoview
function Wait:for_infoview_contents(pattern, iv)
  iv = iv or infoview.get_current_infoview()
  self:_wait(('infoview to contain %q'):format(pattern), function()
    local lines = iv:get_lines()
    return table.concat(lines, '\n'):match(pattern)
  end)
end

---Wait for the Lean server to finish processing ileans.
---@return vim.lsp.Client
function Wait:for_ileans()
  local client = self:for_lsp()
  local params = lsp.make_wait_for_ileans_params()
  client:request_sync('$/lean/waitForILeans', params, self.timeout)
  return client
end

---Wait for the Lean server to finish sending diagnostics.
---@return vim.lsp.Client
function Wait:for_diagnostics()
  local client = self:for_lsp()
  local params = lsp.make_wait_for_diagnostics_params()
  client:request_sync('textDocument/waitForDiagnostics', params, self.timeout)
  return client
end

return setmetatable({}, Wait)
