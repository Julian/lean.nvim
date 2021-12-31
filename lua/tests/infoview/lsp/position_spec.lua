local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')
local position = require('lean._util').make_position_params

helpers.setup {
  infoview = { autoopen = true },
  lsp = { enable = true },
  lsp3 = { enable = true },
}

local lines
describe('infoview pin', function()
  it('setup', function()
      --- setup
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      helpers.wait_for_ready_lsp()
      helpers.wait_for_server_progress()
      vim.api.nvim_win_set_cursor(0, {3, 18})
      assert.initopened.infoview()
      infoview.get_current_infoview().info.pin:set_position_params(position())
      assert.pin_pos_changed.infoview()
      lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  end)

  before_each(function()
    vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
    vim.api.nvim_win_set_cursor(0, {3, 18})
    infoview.get_current_infoview().info.pin:set_position_params(position())
  end)

  describe('does not change position', function()
    it('do not change position when lines changed below',
    function(_)
      vim.api.nvim_buf_set_lines(0, 3, 4, true, {"def boop : Nat := 5"})
      assert.pin_pos_kept.infoview()
      assert.are_equal(2, infoview.get_current_infoview().info.pin.__position_params.position.line)
      assert.are_equal(18, infoview.get_current_infoview().info.pin.__position_params.position.character)
    end)

    it('when lines added below',
    function(_)
      assert.pin_pos_kept.infoview()

      vim.api.nvim_buf_set_lines(0, 4, 5, true, {"", ""})
      assert.pin_pos_kept.infoview()
    end)

    it('when lines removed below',
    function(_)
      assert.pin_pos_kept.infoview()

      vim.api.nvim_buf_set_lines(0, 3, 4, true, {})
      assert.pin_pos_kept.infoview()
    end)

    it('when lines changed above',
    function(_)
      vim.api.nvim_buf_set_lines(0, 1, 2, true, {"def boop : Nat := 5"})
      assert.pin_pos_kept.infoview()
    end)

    it('on change after on same line',
    function(_)
      vim.api.nvim_command("normal! $bia")
      assert.pin_pos_kept.infoview()
    end)
  end)
  describe('updates position', function()
    it('when lines added above',
    function(_)
      vim.api.nvim_buf_set_lines(0, 1, 2, true, {"", ""})
      assert.pin_pos_changed.infoview()
      assert.are_equal(3, infoview.get_current_infoview().info.pin.__position_params.position.line)
      assert.are_equal(18, infoview.get_current_infoview().info.pin.__position_params.position.character)
    end)

    it('on change before on same line',
    function(_)
      assert.pin_pos_changed.infoview()

      vim.api.nvim_command("normal! $bbbeaa")
      assert.pin_pos_changed.infoview()
      assert.are_equal(2, infoview.get_current_infoview().info.pin.__position_params.position.line)
      assert.are_equal(19, infoview.get_current_infoview().info.pin.__position_params.position.character)
    end)
  end)
end)
