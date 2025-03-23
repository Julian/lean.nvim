---@mod lean.lsp LSP

---@brief [[
--- Low-level interaction with the Lean language server.
---@brief ]]

local ms = vim.lsp.protocol.Methods

local log = require 'lean.log'
local util = require 'lean._util'

local lsp = { handlers = {} }

---@class LeanClientCapabilities : lsp.ClientCapabilities
---@field silentDiagnosticSupport? boolean Whether the client supports `DiagnosticWith.isSilent = true`.

---@class LeanClientConfig : vim.lsp.ClientConfig
---@field lean? LeanClientCapabilities

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
      ['$/lean/fileProgress'] = lsp.handlers.file_progress_handler,
      [ms.textDocument_publishDiagnostics] = lsp.handlers.on_publish_diagnostics,
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
  require('lspconfig').leanls.setup(opts)
end

---Find the `vim.lsp.Client` attached to the given buffer.
---@param bufnr? number
---@return vim.lsp.Client?
function lsp.client_for(bufnr)
  local clients = vim.lsp.get_clients { name = 'leanls', bufnr = bufnr or 0 }
  return clients[1]
end

---Custom diagnostic tags provided by the language server.
---We use a separate diagnostic field for this to avoid confusing LSP clients with our custom tags.
---@enum LeanDiagnosticTag
local LeanDiagnosticTag = {
  ---Diagnostics representing an "unsolved goals" error.
  ---Corresponds to `MessageData.tagged `Tactic.unsolvedGoals ..`.
  unsolvedGoals = 1,
  ---Diagnostics representing a "goals accomplished" silent message.
  ---Corresponds to `MessageData.tagged `goalsAccomplished ..`.
  goalsAccomplished = 2,
}

---Represents a diagnostic, such as a compiler error or warning.
---Diagnostic objects are only valid in the scope of a resource.
---
---LSP accepts a `Diagnostic := DiagnosticWith String`.
---The infoview also accepts `InteractiveDiagnostic := DiagnosticWith (TaggedText MsgEmbed)`.
---[reference](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#diagnostic)
---@class DiagnosticWith<M>: { message : M }
---@field range lsp.Range The range at which the message applies.
---@field fullRange? lsp.Range Extension: preserve semantic range of errors when truncating them for display purposes.
---@field severity? lsp.DiagnosticSeverity
---@field isSilent? boolean Extension: whether this diagnostic should not be displayed as a regular diagnostic.
---@field code? string|integer The diagnostic's code, which might appear in the user interface.
---@field source? string A human-readable string describing the source of this diagnostic.
---@field tags? lsp.DiagnosticTag[] Additional metadata about the diagnostic.
---@field leanTags? LeanDiagnosticTag[] Additional Lean-specific metadata about the diagnostic.
---@field relatedInformation? DiagnosticRelatedInformation[] An array of related diagnostic information,
---                                                          e.g. when symbol-names within a scope collide all
---                                                          definitions can be marked via this property.
---@field data? any A data entry field that is preserved between a
---                 `textDocument/publishDiagnostics` notification and
---                 `textDocument/codeAction` request.

---Represents a related message and source code location for a diagnostic.
---This should be used to point to code locations that cause or are related to
---a diagnostics, e.g when duplicating a symbol in a scope.
---@class DiagnosticRelatedInformation
---@field location lsp.Location
---@field message string

---@class LeanFileProgressParams
---@field textDocument lsp.VersionedTextDocumentIdentifier
---@field processing LeanFileProgressProcessingInfo[]

---@class LeanPublishDiagnosticsParams: lsp.PublishDiagnosticsParams
---@field diagnostics DiagnosticWith<string>[]

-- vim.lsp.diagnostic has a *private* `diagnostic_lsp_to_vim` :/ ...

---@param bufnr integer
---@return string[]?
local function get_buf_lines(bufnr)
  if vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local f = io.open(filename)
  if not f then
    return
  end

  local content = f:read '*a'
  if not content then
    -- Some LSP servers report diagnostics at a directory level, in which case
    -- io.read() returns nil
    f:close()
    return
  end

  local lines = vim.split(content, '\n')
  f:close()
  return lines
end

---@param severity lsp.DiagnosticSeverity
local function severity_lsp_to_vim(severity)
  if type(severity) == 'string' then
    severity = vim.lsp.protocol.DiagnosticSeverity[severity] --- @type integer
  end
  return severity
end

--- @param diagnostic lsp.Diagnostic
--- @param client_id integer
--- @return table?
local function tags_lsp_to_vim(diagnostic, client_id)
  local tags ---@type table?
  for _, tag in ipairs(diagnostic.tags or {}) do
    if tag == vim.lsp.protocol.DiagnosticTag.Unnecessary then
      tags = tags or {}
      tags.unnecessary = true
    elseif tag == vim.lsp.protocol.DiagnosticTag.Deprecated then
      tags = tags or {}
      tags.deprecated = true
    else
      vim.lsp.log.info(string.format('Unknown DiagnosticTag %d from LSP client %d', tag, client_id))
    end
  end
  return tags
end

---@param diagnostics DiagnosticWith<string>[]
---@param bufnr integer
---@param client_id integer
---@return vim.Diagnostic[]
local function diagnostic_lsp_to_vim(diagnostics, bufnr, client_id)
  local buf_lines = get_buf_lines(bufnr)
  local client = vim.lsp.get_client_by_id(client_id)
  local position_encoding = client and client.offset_encoding or 'utf-16'
  --- @param diagnostic DiagnosticWith<string>
  --- @return vim.Diagnostic
  return vim.tbl_map(function(diagnostic)
    local start = diagnostic.range.start
    local _end = diagnostic.range['end']
    local line = buf_lines and buf_lines[start.line + 1] or ''
    local end_line = buf_lines and buf_lines[_end.line + 1] or ''

    local ok, col, end_col
    ok, col = pcall(vim.str_byteindex, line, start.character, position_encoding == 'utf-16')
    col = ok and col or start.character
    ok, end_col = pcall(vim.str_byteindex, end_line, _end.character, position_encoding == 'utf-16')
    end_col = ok and end_col or _end.character
    --- @type vim.Diagnostic
    return {
      lnum = start.line,
      col = col,
      end_lnum = _end.line,
      end_col = end_col,
      severity = severity_lsp_to_vim(diagnostic.severity),
      message = diagnostic.message,
      source = diagnostic.source,
      code = diagnostic.code,
      _tags = tags_lsp_to_vim(diagnostic, client_id),
      user_data = {
        lsp = diagnostic,
      },
    }
  end, diagnostics)
end

---The range of a Lean diagnostic.
---
---Prioritizes `fullRange`, which is the "real" range of the diagnostic, not
---the `range`, which clips to just its first line.
---@param diagnostic DiagnosticWith<string>
---@return lsp.Range range
local function range_of(diagnostic)
  return diagnostic.fullRange or diagnostic.range
end

---Convert an LSP position to a (0, 0)-indexed tuple.
---
---These are used by extmarks.
---See `:h api-indexing` for details.
---@param position lsp.Position
---@param line string the line contents for this position's line
---@return { [1]: integer, [2]: integer } position
local function position_to_byte0(position, line)
  local ok, col = pcall(vim.str_byteindex, line, position.character, true)
  return { position.line, ok and col or position.character }
end

---Convert Lean ranges to byte indices.
---
---Prioritizes `fullRange`, which is the "real" range of the diagnostic, not
---the `range`, which clips to just its first line.
---
---Returned positions are 0-indexed.
---@param bufnr integer
---@param diagnostic DiagnosticWith<string>
---@return integer start_row
---@return integer start_col
---@return integer end_row
---@return integer end_col
local function byterange_of(bufnr, diagnostic)
  local range = range_of(diagnostic)
  local start_line =
    vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, true)[1]
  local start = position_to_byte0(range.start, start_line)

  local end_line =
    vim.api.nvim_buf_get_lines(bufnr, range['end'].line, range['end'].line + 1, true)[1]
  local _end = position_to_byte0(range['end'], end_line)
  return start[1], start[2], _end[1], _end[2]
end

---A namespace where we put Lean's "silent" diagnostics.
local silent_ns = vim.api.nvim_create_namespace 'lean.diagnostic.silent'
---A namespace for Lean's unsolved goal markers.and goals accomplished ranges
local goals_ns = vim.api.nvim_create_namespace 'lean.goals'

---Is the given line within a range of a goals accomplished marker?
---@param bufnr? integer
---@param line? integer a 0--indexed line number in the buffer
---@return boolean is_accomplished
function lsp.goals_accomplished_on(bufnr, line)
  bufnr = bufnr or 0
  line = line or (vim.api.nvim_win_get_cursor(0)[1] - 1)
  local pos = { line, 0 }
  local hls = vim.api.nvim_buf_get_extmarks(bufnr, goals_ns, pos, pos, {
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

---Is this a goals accomplished diagnostic?
---@generic T
---@param diagnostic DiagnosticWith<T>
---@return boolean
function lsp.is_unsolved_goals_diagnostic(diagnostic)
  return vim.deep_equal(diagnostic.leanTags, { LeanDiagnosticTag.unsolvedGoals })
end

---Is this a goals accomplished diagnostic?
---@generic T
---@param diagnostic DiagnosticWith<T>
---@return boolean
function lsp.is_goals_accomplished_diagnostic(diagnostic)
  return vim.deep_equal(diagnostic.leanTags, { LeanDiagnosticTag.goalsAccomplished })
end

---A replacement handler for diagnostic publishing for Lean-specific behavior.
---
---Publishes all "silent" Lean diagnostics to a separate namespace, and creates
---unsolved goals markers (in yet another namespace).
---@param result LeanPublishDiagnosticsParams
---@param ctx lsp.HandlerContext
---@param config? vim.diagnostic.Opts
function lsp.handlers.on_publish_diagnostics(_, result, ctx, config)
  local bufnr = vim.uri_to_bufnr(result.uri)
  vim.diagnostic.reset(silent_ns, bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, goals_ns, 0, -1)

  local other_silent = {}

  result.diagnostics = vim
    .iter(result.diagnostics)
    ---@param each DiagnosticWith<string>
    :filter(function(each)
      local range = range_of(each)
      if lsp.is_unsolved_goals_diagnostic(each) then
        local buf_lines = get_buf_lines(bufnr)
        local end_line = buf_lines[range['end'].line + 1] or ''
        local end_row, end_col = unpack(position_to_byte0(range['end'], end_line))

        vim.api.nvim_buf_set_extmark(bufnr, goals_ns, end_row, end_col, {
          hl_mode = 'combine',
          virt_text = { { ' ⚒ ', 'leanUnsolvedGoals' } },
          virt_text_pos = 'overlay',
        })
      elseif lsp.is_goals_accomplished_diagnostic(each) then
        local start_row, start_col, end_row, end_col = byterange_of(bufnr, each)
        vim.api.nvim_buf_set_extmark(bufnr, goals_ns, start_row, start_col, {
          sign_text = '🎉',
          sign_hl_group = 'leanGoalsAccomplishedSign',
        })
        vim.api.nvim_buf_set_extmark(bufnr, goals_ns, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = 'leanGoalsAccomplished',
          hl_mode = 'combine',
          conceal = '🎉',
        })
      end

      return not each.isSilent
    end)
    :totable()

  vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)

  vim.diagnostic.set(silent_ns, bufnr, diagnostic_lsp_to_vim(other_silent, bufnr, ctx.client_id), {
    underline = false,
    virtual_text = false,
    update_in_insert = false,
  })
end

---Called when `$/lean/fileProgress` is triggered.
---@param err LspError?
---@param params LeanFileProgressParams
function lsp.handlers.file_progress_handler(err, params)
  log:trace {
    message = 'got fileProgress',
    err = err,
    params = params,
  }

  if err ~= nil then
    return
  end

  require('lean.progress').update(params)
  -- XXX: Similar to the equivalent line below, this second pcall seems to have
  --      become necessary when we started deleting clean buffers in tests.
  --      That's.. very suspicious, because it probably means it's necessary
  --      for "real life" use cases as well. So something isn't being handled
  --      correctly here. Without this though, tests in the sorry spec?? and
  --      not others seem to fail nondeterministically around 50% of the time.
  pcall(require('lean.infoview').__update_pin_by_uri, params.textDocument.uri)

  require('lean.progress_bars').update(params)
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

  client.notify(ms.textDocument_didClose, { textDocument = { uri = uri } })
  client.notify(ms.textDocument_didOpen, {
    textDocument = {
      version = 0,
      uri = uri,
      languageId = 'lean',
      text = util.buf_get_full_text(bufnr),
    },
  })
end

---@class PlainGoal
---@field rendered string The goals as pretty-printed Markdown, or something like "no goals" if accomplished.
---@field goals string[] The pretty-printed goals, empty if all accomplished.

---Fetch goal state information from the server (async).
---@param params lsp.TextDocumentPositionParams
---@param bufnr number
---@return LspError|nil error
---@return PlainGoal|nil plain_goal
function lsp.plain_goal(params, bufnr)
  local client = lsp.client_for(bufnr)
  if not client then
    return 'LSP server not connected', nil
  end

  params = vim.deepcopy(params)
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  params.position.character = params.position.character + 1
  return util.client_a_request(client, '$/lean/plainGoal', params)
end

---@class PlainTermGoal
---@field goal string
---@field range lsp.Range

---Fetch term goal state information from the server (async).
---@param params lsp.TextDocumentPositionParams
---@param bufnr number
---@return LspError|nil error
---@return PlainTermGoal|nil plain_term_goal
function lsp.plain_term_goal(params, bufnr)
  local client = lsp.client_for(bufnr)
  if not client then
    return 'LSP server not connected', nil
  end
  return util.client_a_request(client, '$/lean/plainTermGoal', params)
end

return lsp
