---@brief [[
--- Tests for codicon rendering.
---@brief ]]

local Buffer = require 'std.nvim.buffer'

local Element = require('lean.tui').Element
local codicons = require 'tui.codicons'
local kitty = require 'kitty'

require 'spec.helpers'

local SPARKLE = vim.fn.nr2char(0xEC10, 1)

---Point the module at a local fake of the codicons repository.
---@param mapping table the contents of `mapping.json`
local function fake_repository(mapping)
  local repository = vim.fn.tempname()
  local template = vim.fs.joinpath(repository, 'src', 'template')
  vim.fn.mkdir(template, 'p')
  local file = assert(io.open(vim.fs.joinpath(template, 'mapping.json'), 'w'))
  file:write(vim.json.encode(mapping))
  file:close()
  codicons.base_url = 'file://' .. repository .. '/'
  codicons.cache_dir = vim.fn.tempname()
end

describe('codicons', function()
  it('renders nothing when no icon rendering is possible', function()
    if kitty.available() then
      pending 'kitty is available in this terminal'
      return
    end
    assert.is_nil(vim.g.have_nerd_font)
    assert.is_nil(codicons.element 'sparkle')
  end)

  it('lazily downloads the glyph mapping, showing a fallback meanwhile', function()
    if kitty.available() then
      pending 'kitty is available in this terminal'
      return
    end

    fake_repository { [tostring(0xEC10)] = { 'sparkle' } }
    vim.g.have_nerd_font = true

    local element = assert(codicons.element('sparkle', {
      fallback = Element:new { text = '[sparkle]' },
    }))
    local buffer = Buffer.create { scratch = true }
    local renderer = element:renderer { buffer = buffer }
    renderer:render()

    assert.contents.are { '[sparkle]', buffer = buffer }

    local resolved = vim.wait(10000, function()
      local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
      return table.concat(lines, '\n') == SPARKLE
    end)
    assert.message('icon did not resolve to its glyph').is_true(resolved)
  end)

  it('renders already-known glyphs synchronously', function()
    if kitty.available() then
      pending 'kitty is available in this terminal'
      return
    end
    vim.g.have_nerd_font = true
    local element = assert(codicons.element 'sparkle')
    assert.is.equal(SPARKLE, element:to_string())
  end)

  it('renders nothing for icons with no known glyph', function()
    if kitty.available() then
      pending 'kitty is available in this terminal'
      return
    end
    vim.g.have_nerd_font = true
    assert.is_nil(codicons.element 'not-a-real-codicon')
  end)
end)
