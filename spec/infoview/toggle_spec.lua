require 'spec.helpers'
local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

describe('Infoview.toggle', function()
  local lean_window

  it('closes an open infoview', function()
    assert.is.equal(1, #Tab:current():windows())
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    lean_window = Window:current()
    local current_infoview = infoview.get_current_infoview()

    assert.windows.are { lean_window, current_infoview.window }

    current_infoview:toggle()
    assert.windows.are { lean_window }
  end)

  it('opens a closed infoview', function()
    assert.windows.are { lean_window }
    local current_infoview = infoview.get_current_infoview()
    current_infoview:toggle()
    assert.windows.are { lean_window, current_infoview.window }
  end)

  it('toggles back and forth', function()
    local current_infoview = infoview.get_current_infoview()
    assert.windows.are { lean_window, current_infoview.window }

    current_infoview:toggle()
    assert.windows.are { lean_window }

    current_infoview:toggle()
    assert.windows.are { lean_window, current_infoview.window }

    current_infoview:toggle()
    assert.windows.are { lean_window }
  end)

  describe('when the infoview is the last window', function()
    it('quits Neovim, as :quit would', function()
      -- Run this in a separate Neovim, since it (should) exit!
      local minimal_init = vim.fs.joinpath(vim.fn.getcwd(), 'scripts', 'minimal_init.lua')
      local script = ([[
        vim.cmd.edit(%q)
        local infoview = require 'lean.infoview'
        infoview.go_to()
        vim.cmd.only()
        infoview.get_current_infoview():toggle()
        print 'still alive'
        vim.cmd.qall { bang = true }
      ]]):format(fixtures.project.some_existing_file)
      local result = vim
        .system({ 'nvim', '--headless', '--clean', '-u', minimal_init, '-c', 'lua ' .. script })
        :wait()
      assert.is.equal(0, result.code, result.stderr)
      assert.has_no.match('still alive', result.stdout .. result.stderr)
    end)

    it('refuses to quit if there are unsaved changes', function()
      local current_infoview = infoview.get_current_infoview()
      current_infoview:open()
      assert.windows.are { lean_window, current_infoview.window }

      -- Leave the infoview as the only window in the tab.
      current_infoview:enter()
      vim.cmd.only()
      local window = current_infoview.window
      assert.windows.are { window }

      local unsaved = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(unsaved, 0, -1, false, { 'unsaved' })

      assert.error_matches(function()
        current_infoview:toggle()
      end, 'E37')
      assert.windows.are { window }
      assert.are.same(window, current_infoview.window)

      vim.api.nvim_buf_delete(unsaved, { force = true })
    end)

    it('closes just its tab if there are others', function()
      local tab = Tab:current()
      local current_infoview = infoview.get_current_infoview()
      assert.is.truthy(current_infoview.window)

      vim.cmd.tabedit(fixtures.project.some_existing_file)
      local other_tab = Tab:current()
      local other_infoview = infoview.get_current_infoview()
      assert.are_not.same(current_infoview, other_infoview)

      other_infoview:enter()
      vim.cmd.only()
      assert.windows.are { other_infoview.window }

      other_infoview:toggle()

      assert.is_nil(other_infoview.window)
      assert.is_false(vim.api.nvim_tabpage_is_valid(other_tab.id))
      assert.current_tabpage.is(tab)
      assert.windows.are { current_infoview.window }
    end)
  end)
end)
