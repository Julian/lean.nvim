---@brief [[
--- Stuff that should live in some standard library.
---@brief ]]

local M = {}

---Fetch the diagnostics for all Lean LSP clients from the current buffer.
---@param opts? table
---@param bufnr? number buffer handle or 0 for current, defaults to current
---@return vim.Diagnostic[] diagnostics the relevant Lean diagnostics
function M.lean_lsp_diagnostics(opts, bufnr)
  bufnr = bufnr or 0
  local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'leanls' }
  local namespaces = vim.iter(clients):map(function(client)
    return vim.lsp.diagnostic.get_namespace(client.id)
  end)
  return vim.diagnostic.get(
    bufnr,
    vim.tbl_extend('keep', opts or {}, { namespace = namespaces:totable() })
  )
end

---@class CreateBufParams
---@field name? string the name of the new buffer
---@field options? table<string, any> a table of buffer options
---@field listed? boolean see :h nvim_create_buf (default true)
---@field scratch? boolean see :h nvim_create_buf (default false)

---Create a new buffer.
---@param params CreateBufParams new buffer options
---@return integer bufnr the new bufnr
function M.create_buf(params)
  if params.listed == nil then
    params.listed = true
  end
  if params.scratch == nil then
    params.scratch = false
  end
  local bufnr = vim.api.nvim_create_buf(params.listed, params.scratch)
  for option, value in pairs(params.options or {}) do
    vim.bo[bufnr][option] = value
  end
  if params.name ~= nil then
    vim.api.nvim_buf_set_name(bufnr, params.name)
  end
  return bufnr
end

---Simple alternative to vim.lsp.util._make_floating_popup_size
function M.make_floating_popup_size(contents)
  return unpack(vim.iter(contents):fold({ 0, 0 }, function(acc, line)
    local width, height = unpack(acc)
    return {
      math.max(width, vim.fn.strdisplaywidth(line)),
      height + 1,
    }
  end))
end

---@class UIParams
---@field textDocument { uri: string }
---@field position { line: uinteger, character: uinteger }

---Check that the given position parameters are valid given the buffer they correspond to.
---@param params UIParams parameters to verify
---@return boolean
function M.position_params_valid(params)
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

  local line = params.position.line + 1

  if line > #lines then
    return false
  end

  if params.position.character > #lines[line] - 1 then
    return false
  end

  return true
end

function M.make_position_params()
  local line, character = unpack(vim.api.nvim_win_get_cursor(0))
  return {
    textDocument = { uri = vim.uri_from_bufnr(0) },
    position = {
      line = line - 1,
      character = character,
    },
  }
end

return M
