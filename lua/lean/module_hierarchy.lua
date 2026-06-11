---@mod lean.module_hierarchy Module Hierarchy

---@brief [[
--- Querying the Lean module import graph.
---
--- Provides access to the module hierarchy LSP requests introduced in
--- Lean 4.22, allowing callers to explore what a module imports and what
--- imports it.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'
local async = require 'std.async'

local Element = require('lean.tui').Element
local lsp = require 'lean.lsp'

---Buffer-local key bindings for the hierarchy panel. Defined here (not via
---`infoview.mappings`) because that runtime variable is on the deprecation
---path -- see commit 892006e9, scheduled for removal in v2026.9.1.
local PANEL_KEYMAPS = {
  ['<Tab>'] = 'click',
  ['<CR>'] = 'go_to_def',
  ['gd'] = 'go_to_def',
  ['<LocalLeader><Tab>'] = 'goto_last_window',
}

---@class LeanModule
---@field name string the human-readable module name
---@field uri lsp.DocumentUri the file URI
---@field data? any optional server-specific data

---@class LeanImportKind
---@field isPrivate boolean whether this is a private import
---@field isAll boolean whether this is an `open ... in` style import
---@field metaKind 'nonMeta'|'meta'|'full' the meta kind of the import

---@class LeanImport
---@field module LeanModule the imported module
---@field kind LeanImportKind metadata about the import

local module_hierarchy = {}

---Describe the kind of an import in human-readable form.
---
---Returns nil for a plain import with no special modifiers.
---@param kind LeanImportKind
---@return string? description e.g. "[private, meta]"
function module_hierarchy.describe_import_kind(kind)
  local parts = {}
  if kind.isPrivate then
    table.insert(parts, 'private')
  end
  if kind.isAll then
    table.insert(parts, 'all')
  end
  if kind.metaKind == 'meta' then
    table.insert(parts, 'meta')
  elseif kind.metaKind == 'full' then
    table.insert(parts, 'meta + non-meta')
  end
  if #parts == 0 then
    return nil
  end
  return '[' .. table.concat(parts, ', ') .. ']'
end

---LSP `MethodNotFound` error code; emitted when the server doesn't recognize a
---request method (here, when the user is on Lean &lt; 4.22).
local METHOD_NOT_FOUND = -32601

---Send a module-hierarchy LSP request.
---@param bufnr number
---@param method string
---@param params table
---@return any? result
---@return string? err a user-facing error message
local function request(bufnr, method, params)
  local client = lsp.client_for(bufnr)
  if not client then
    return nil, 'No Lean LSP client attached.'
  end
  local err, result = lsp.request(client, method, params)
  if err then
    if err.code == METHOD_NOT_FOUND then
      return nil, 'requires Lean 4.22 or newer.'
    end
    return nil, err.message or vim.inspect(err)
  end
  return result, nil
end

---Get the module corresponding to a buffer's file.
---@param bufnr? number the buffer number, defaulting to 0
---@return LeanModule? module
---@return string? err
function module_hierarchy.prepare(bufnr)
  bufnr = bufnr or 0
  return request(bufnr, '$/lean/prepareModuleHierarchy', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
  })
end

---Get the imports of a module.
---@param module LeanModule the module to query
---@param bufnr? number a buffer attached to the relevant LSP client
---@return LeanImport[]? imports
---@return string? err
function module_hierarchy.imports(module, bufnr)
  return request(bufnr or 0, '$/lean/moduleHierarchy/imports', { module = module })
end

---Get the modules that import a given module.
---@param module LeanModule the module to query
---@param bufnr? number a buffer attached to the relevant LSP client
---@return LeanImport[]? imports
---@return string? err
function module_hierarchy.imported_by(module, bufnr)
  return request(bufnr or 0, '$/lean/moduleHierarchy/importedBy', { module = module })
end

local INDENT = '  '

---Build a foldable tree node for a module and its (lazily-fetched) children.
---@param mod LeanModule
---@param fetch fun(module: LeanModule, bufnr?: number): LeanImport[]?, string?
---@param bufnr number
---@param open_in fun(uri: lsp.DocumentUri) opens the given module file in the source window
---@param depth integer nesting depth (root is 0); used for indentation
---@param description? string annotation shown to the right (e.g. "[private]")
---@return Element
local function tree_node(mod, fetch, bufnr, open_in, depth, description)
  local title_children = { Element:new { text = mod.name } }
  if description then
    table.insert(
      title_children,
      Element:new { text = ' ' .. description, hlgroups = { 'Comment' } }
    )
  end
  local title = Element:new { children = title_children }

  local fetched = false
  local child_indent = INDENT:rep(depth + 1)
  return Element:foldable {
    title = title,
    body = {},
    open = false,
    gap = 1,
    -- The indent is part of the title row (not an outer wrapper) so clicks
    -- and gd fire from any column on the line, not just past the indent.
    before_arrow = depth > 0 and Element:new { text = INDENT:rep(depth) } or nil,
    events = {
      go_to_def = function()
        open_in(mod.uri)
      end,
    },
    on_open = function(body)
      if fetched then
        return
      end
      fetched = true
      local imports, err = fetch(mod, bufnr)
      if err then
        body:set_children {
          Element:new { text = child_indent .. err, hlgroups = { 'ErrorMsg' } },
        }
      elseif #imports == 0 then
        body:set_children {
          Element:new { text = child_indent .. '(none)', hlgroups = { 'Comment' } },
        }
      else
        local child_nodes = vim
          .iter(imports)
          :map(function(imp)
            return tree_node(
              imp.module,
              fetch,
              bufnr,
              open_in,
              depth + 1,
              module_hierarchy.describe_import_kind(imp.kind)
            )
          end)
          :totable()
        body:set_children { Element:concat(child_nodes, '\n') }
      end
    end,
  }
end

---Open panels, keyed by tabpage id so each tab tracks its own. We only ever
---show one direction (imports vs imported_by) per tab, so a single window is
---enough.
---@type table<integer, { kind: 'imports'|'imported_by', win: Window }>
local panels = {}

---@type fun(kind: 'imports'|'imported_by'): nil
local show

---Namespace for the loading-state orange bars.
local LOADING_NS = vim.api.nvim_create_namespace 'lean.module_hierarchy.loading'

---Fill the panel buffer with a placeholder + sign-column orange bars matching
---the pattern Lean uses for in-progress regions (`leanProgressBar`). Cleared
---when the real tree renders.
---@param buf Buffer
---@param win Window
---@param kind 'imports'|'imported_by'
local function show_loading(buf, win, kind)
  local label = ('Loading %s...'):format(kind == 'imports' and 'imports' or 'importers')
  local height = win:height()
  local lines = { label }
  for _ = 2, height do
    table.insert(lines, '')
  end

  buf.o.modifiable = true
  buf:set_lines(lines)
  buf.o.modifiable = false

  -- Reuse the progress bar sign so loading looks like in-progress Lean files.
  local options = require 'lean.config'().progress_bars
  for line = 0, height - 1 do
    buf:set_extmark(LOADING_NS, line, 0, {
      sign_text = options.character,
      sign_hl_group = 'leanProgressBar',
      priority = options.priority,
    })
  end
end

show = function(kind)
  local tab_id = Tab:current().id
  ---@type { kind: 'imports'|'imported_by', win: Window }?
  local existing = panels[tab_id]
  if existing and not existing.win:is_valid() then
    panels[tab_id] = nil
    existing = nil
  end

  -- Same-kind invocation: just focus the panel the user already has, even if
  -- they're now sitting on a non-Lean buffer. They asked to see their panel.
  if existing and existing.kind == kind then
    existing.win:make_current()
    return
  end

  -- We're going to open a new panel, so we need an LSP attached. Bail before
  -- touching anything else (so an opposite-direction panel doesn't get closed
  -- only to surface an error).  Lean < 4.22 still goes through the panel-
  -- then-close path since it's only detectable after sending the request.
  local source_win = Window:current()
  local source_buf = source_win:buffer()
  if not lsp.client_for(source_buf.bufnr) then
    vim.notify('Module hierarchy: No Lean LSP client attached.', vim.log.levels.WARN)
    return
  end

  -- Different direction requested -- close the old panel so the user never has
  -- to mentally juggle two stale views in one tab. With LSP-attached above, we
  -- know the source window is open, so the panel isn't alone and force_close
  -- can't take nvim down.
  if existing then
    existing.win:force_close()
    panels[tab_id] = nil
  end

  local fetch, title_prefix
  if kind == 'imports' then
    fetch, title_prefix = module_hierarchy.imports, 'Imports of '
  else
    fetch, title_prefix = module_hierarchy.imported_by, 'Importers of '
  end

  ---Open the given module file in the source window the panel was opened from.
  ---@param uri lsp.DocumentUri
  local function open_in(uri)
    if not source_win:is_valid() then
      vim.notify('Module hierarchy: source window is gone, cannot jump.', vim.log.levels.WARN)
      return
    end
    source_win:make_current()
    vim.cmd.edit(vim.uri_to_fname(uri))
  end

  -- Open the panel synchronously so the user sees immediate acknowledgment;
  -- populate it from the LSP response below. Loading bars sit in the sign
  -- column until the tree replaces them.
  local buf = Buffer.create {
    scratch = true,
    listed = false,
    options = { bufhidden = 'wipe', filetype = 'leaninfo' },
  }
  local win = source_win:split { buffer = buf, enter = true, direction = 'right' }
  panels[tab_id] = { kind = kind, win = win }
  show_loading(buf, win, kind)

  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win.id),
    once = true,
    callback = function()
      if panels[tab_id] and panels[tab_id].win.id == win.id then
        panels[tab_id] = nil
      end
    end,
  })

  buf.keymaps:set('n', 'r', function()
    if not source_win:is_valid() then
      vim.notify('Module hierarchy: source window is gone, cannot refresh.', vim.log.levels.WARN)
      return
    end
    source_win:make_current()
    pcall(function()
      win:force_close()
    end)
    show(kind)
  end, { desc = 'Refresh the module hierarchy.' })

  async.run(function()
    local mod, err = module_hierarchy.prepare(source_buf.bufnr)
    if not mod then
      vim.notify(('Module hierarchy: %s'):format(err or 'not available'), vim.log.levels.WARN)
      pcall(function()
        win:force_close()
      end)
      return
    end

    local imports, fetch_err = fetch(mod, source_buf.bufnr)
    local children
    if fetch_err then
      children = { Element:new { text = fetch_err, hlgroups = { 'ErrorMsg' } } }
    elseif #imports == 0 then
      children = { Element:new { text = '(none)', hlgroups = { 'Comment' } } }
    else
      children = vim
        .iter(imports)
        :map(function(imp)
          return tree_node(
            imp.module,
            fetch,
            source_buf.bufnr,
            open_in,
            0,
            module_hierarchy.describe_import_kind(imp.kind)
          )
        end)
        :totable()
    end

    local tree = Element:concat(children, '\n')
    local root = Element:new {
      children = {
        Element:new {
          children = {
            Element:new { text = title_prefix, hlgroups = { 'Comment' } },
            Element.title(mod.name),
          },
        },
        Element:new { text = '\n' },
        Element:new {
          text = '<Tab> toggle · <CR> open · r refresh',
          hlgroups = { 'Comment' },
        },
        Element:new { text = '\n\n' },
        tree,
      },
    }

    -- The user may have closed the panel while we were waiting on the LSP.
    if not buf:is_valid() or not win:is_valid() then
      return
    end

    buf:clear_namespace(LOADING_NS)
    root:renderer({ buffer = buf, keymaps = PANEL_KEYMAPS }):render()

    -- Land the cursor on the first tree node so <Tab>/<CR> work immediately.
    local first = buf:call(function()
      return vim.fn.search('[▶▼]', 'cnW')
    end)
    if first > 0 then
      pcall(function()
        win:set_cursor { first, 0 }
      end)
    end
  end)
end

---Show the imports of the current module in a tree view.
function module_hierarchy.show_imports()
  show 'imports'
end

---Show the modules that import the current module in a tree view.
function module_hierarchy.show_imported_by()
  show 'imported_by'
end

return module_hierarchy
