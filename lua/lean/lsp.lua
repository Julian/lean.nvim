---@mod lean.lsp LSP

---@brief [[
--- Low-level interaction with the Lean language server.
---@brief ]]

local ms = vim.lsp.protocol.Methods

local Buffer = require 'std.nvim.buffer'
local std = require 'std.lsp'

local config = require 'lean.config'
local diagnostic = require 'lean.diagnostic'
local log = require 'lean.log'

local lsp = { handlers = {} }

---@class LeanClientCapabilities : lsp.ClientCapabilities
---@field silentDiagnosticSupport? boolean Whether the client supports `DiagnosticWith.isSilent = true`.

---@class LeanClientConfig : vim.lsp.ClientConfig
---@field lean? LeanClientCapabilities

---Find the `vim.lsp.Client` attached to the given buffer.
---@param bufnr? number
---@return vim.lsp.Client?
function lsp.client_for(bufnr)
  local clients = vim.lsp.get_clients { name = 'leanls', bufnr = bufnr or 0 }
  return clients[1]
end

---A namespace where we put Lean's "silent" diagnostics.
local silent_ns = vim.api.nvim_create_namespace 'lean.diagnostic.silent'
---A namespace for Lean's unsolved goal markers.and goals accomplished ranges
local goals_ns = vim.api.nvim_create_namespace 'lean.goal.markers'

---Is the given line within a range of a goals accomplished marker?
---@param params lsp.TextDocumentPositionParams the document position in question
---@return boolean? accomplished whether there's a marker at the cursor, or nil if the buffer isn't loaded
function lsp.goals_accomplished_at(params)
  local buffer = Buffer:from_uri(params.textDocument.uri)
  if not buffer:is_loaded() then
    return
  end

  local pos = { params.position.line, 0 }
  local hls = vim.api.nvim_buf_get_extmarks(buffer.bufnr, goals_ns, pos, pos, {
    details = true,
    overlap = true,
    type = 'highlight',
  })
  return vim.iter(hls):any(function(hl)
    return hl[4].hl_group == 'leanGoalsAccomplished'
  end)
end

vim.cmd.highlight [[default link leanUnsolvedGoals DiagnosticInfo]]
vim.cmd.highlight [[default link leanGoalsAccomplishedSign DiagnosticInfo]]

---A replacement handler for diagnostic publishing for Lean-specific behavior.
---
---Publishes all "silent" Lean diagnostics to a separate namespace, and creates
---unsolved goals markers (in yet another namespace).
---@param result LeanPublishDiagnosticsParams
---@param ctx lsp.HandlerContext
local function on_publish_diagnostics(_, result, ctx)
  local buffer = Buffer:from_uri(result.uri)
  vim.diagnostic.reset(silent_ns, buffer.bufnr)
  buffer:clear_namespace(goals_ns)

  local markers = config().goal_markers

  ---@type { [1]: integer, [2]: integer }[]
  local unsolved = {}
  local other_silent = {}

  result.diagnostics = vim
    .iter(result.diagnostics)
    ---@param each DiagnosticWith<string>
    :filter(function(each)
      local range = diagnostic.range_of(each)
      -- Protect setting markers with a pcall, which seems like it can happen
      -- if we're still processing diagnostics but the buffer has already
      -- changed, which can give out of range errors when setting the extmarks.
      local succeeded = pcall(function()
        if markers.unsolved ~= '' and diagnostic.is_unsolved_goals(each) then
          table.insert(unsolved, std.position_to_byte0(range['end'], buffer.bufnr))
        elseif markers.accomplished ~= '' and diagnostic.is_goals_accomplished(each) then
          local start_row, start_col, end_row, end_col = diagnostic.byterange_of(buffer.bufnr, each)
          buffer:set_extmark(goals_ns, start_row, start_col, {
            sign_text = markers.accomplished,
            sign_hl_group = 'leanGoalsAccomplishedSign',
          })
          buffer:set_extmark(goals_ns, start_row, start_col, {
            end_row = end_row,
            end_col = end_col,
            hl_group = 'leanGoalsAccomplished',
            hl_mode = 'combine',
          })
        end
      end)
      if not succeeded then
        log:debug {
          message = 'Failed to set goals accomplished markers',
          diagnostic = each,
          bufnr = buffer.bufnr,
        }
      end

      return not each.isSilent
    end)
    :totable()

  vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx)

  if #unsolved ~= 0 then
    local function place_marker(pos)
      local succeeded = pcall(Buffer.set_extmark, buffer, goals_ns, pos[1], pos[2], {
        hl_mode = 'combine',
        virt_text = { { markers.unsolved, 'leanUnsolvedGoals' } },
        virt_text_pos = 'eol',
      })
      if not succeeded then
        log:debug {
          message = 'Failed to set unsolved goal marker',
          bufnr = buffer.bufnr,
        }
      end
    end

    local function place_all()
      vim.iter(unsolved):each(place_marker)
      unsolved = {} -- so we don't place 2 markers on hold + insert leave
    end

    local mode = vim.api.nvim_get_mode().mode
    if mode == 'i' then
      buffer:create_autocmd({ 'InsertLeave', 'CursorHoldI' }, {
        group = vim.api.nvim_create_augroup('LeanUnsolvedGoalsMarkers', {}),
        callback = place_all,
        once = true,
        desc = 'place unsolved goals markers',
      })
    else
      place_all()
    end
  end

  vim.diagnostic.set(
    silent_ns,
    buffer.bufnr,
    diagnostic.leanls_to_vim(other_silent, buffer.bufnr, ctx.client_id),
    {
      underline = false,
      virtual_text = false,
      update_in_insert = false,
    }
  )
end

---Called when `$/lean/fileProgress` is triggered.
---@param err LspError?
---@param params LeanFileProgressParams
local function file_progress_handler(err, params)
  if err ~= nil then
    log:error {
      message = 'fileProgress error',
      err = err,
      params = params,
    }
    return
  else
    log:trace {
      message = 'got fileProgress',
      err = err,
      params = params,
    }
  end

  require('lean.progress').update(params)
  require('lean.progress_bars').update(params)

  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    log:warning {
      message = 'updating fileProgress for an unloaded buffer',
      bufnr = bufnr,
      err = err,
      params = params,
    }
    return
  end

  require('lean.infoview').__update_pin_by_uri(params.textDocument.uri)
end

---@param opts LeanClientConfig
function lsp.enable(opts)
  opts.capabilities = opts.capabilities or vim.lsp.protocol.make_client_capabilities()
  opts = vim.tbl_deep_extend('keep', opts, {
    capabilities = {
      lean = {
        silentDiagnosticSupport = true,
      },
    },
    handlers = {
      ['$/lean/fileProgress'] = file_progress_handler,
      [ms.textDocument_publishDiagnostics] = on_publish_diagnostics,
    },
    init_options = {
      editDelay = 10, -- see #289
      hasWidgets = true,
    },
    on_init = function(_, response)
      local version = response.serverInfo.version
      ---Lean 4.19 introduces silent diagnostics, which we use to differentiate
      ---between "No goals." and "Goals accomplished. For older versions, we
      ---always say the latter (which is consistent with `lean.nvim`'s historic
      ---behavior, albeit not with VSCode's).
      ---
      ---Technically this being a global is wrong, and will mean we start
      ---showing the wrong message if someone opens an older Lean buffer in the
      ---same session as a newer one...
      vim.g.lean_no_goals_message = vim.version.ge(version, '0.3.0') and 'No goals.'
        or 'Goals accomplished 🎉'
    end,
  })
  vim.lsp.config('leanls', opts)
end

---Restart the Lean server for an open Lean 4 file.
---See e.g. https://github.com/leanprover/lean4/blob/master/src/Lean/Server/README.md#recompilation-of-opened-files
---@param bufnr? number
function lsp.restart_file(bufnr)
  bufnr = bufnr or 0
  local client = lsp.client_for(bufnr)
  if not client then
    log:info {
      message = "Cannot refresh file dependencies, this isn't a Lean file.",
      bufnr = bufnr,
    }
    return
  end
  local uri = vim.uri_from_bufnr(bufnr)

  client:notify(ms.textDocument_didClose, { textDocument = { uri = uri } })
  client:notify(ms.textDocument_didOpen, {
    textDocument = {
      version = 0,
      uri = uri,
      languageId = 'lean',
      text = std.buf_get_full_text(bufnr),
    },
  })
end

return lsp
