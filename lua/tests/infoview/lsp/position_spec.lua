local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')
local position = require('vim.lsp.util').make_position_params

helpers.setup {
  infoview = { autoopen = true },
  lsp = { enable = true },
  lsp3 = { enable = true },
}

vim.api.nvim_command("edit " .. fixtures.lean_project.some_existing_file)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

describe('infoview pin', function()
  before_each(function()
    vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
    vim.api.nvim_win_set_cursor(0, {3, 18})
    infoview.get_current_infoview().info.pin:set_position_params(position())
  end)

  describe('does not change position', function()
    it('do not change position when lines changed below',
    function(_)
      --- setup
      helpers.wait_for_ready_lsp()
      helpers.wait_for_server_progress()
      assert.initopened.infoview()
      assert.are_equal(2, infoview.get_current_infoview().info.pin.position_params.position.line)
      assert.are_equal(18, infoview.get_current_infoview().info.pin.position_params.position.character)

      vim.api.nvim_buf_set_lines(0, 3, 4, true, {"def boop : Nat := 5"})
      assert.pin_pos_kept.infoview()
    end)

    it('when lines added below',
    function(_)
      vim.api.nvim_buf_set_lines(0, 3, 4, true, {"", ""})
      assert.pin_pos_kept.infoview()
    end)

    it('when lines removed below',
    function(_)
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
      vim.api.nvim_buf_set_lines(0, 2, 3, true, {"def test1 : Nat := atest"})
      assert.pin_pos_kept.infoview()
    end)
  end)
  describe('updates position', function()
    it('when lines added above',
    function(_)
      vim.api.nvim_buf_set_lines(0, 1, 2, true, {"", ""})
      assert.pin_pos_changed.infoview()
      assert.are_equal(3, infoview.get_current_infoview().info.pin.position_params.position.line)
      assert.are_equal(18, infoview.get_current_infoview().info.pin.position_params.position.character)
    end)

    it('on change before on same line',
    function(_)
      assert.pin_pos_changed.infoview()

      vim.api.nvim_buf_set_lines(0, 2, 3, true, {"def test1 : Nat :=a test"})
      assert.pin_pos_changed.infoview()
      assert.are_equal(2, infoview.get_current_infoview().info.pin.position_params.position.line)
      assert.are_equal(19, infoview.get_current_infoview().info.pin.position_params.position.character)
    end)

    it('on multi-line change',
    function(_)
      assert.pin_pos_changed.infoview()

      vim.api.nvim_buf_set_lines(0, 1, 3, true, {"asdf", "def test1 : Nat :=a test"})
      assert.pin_pos_changed.infoview()
      assert.are_equal(2, infoview.get_current_infoview().info.pin.position_params.position.line)
      assert.are_equal(19, infoview.get_current_infoview().info.pin.position_params.position.character)
    end)
  end)
  describe('invalidates position', function()
    it('within interior line of multi-line change',
    function(_)
      assert.pin_pos_changed.infoview()

      vim.api.nvim_buf_set_lines(0, 1, 4, true, {"  ", "  def test1 : Nat := test", "  "})
      assert.pin_pos_changed.infoview()
      assert.is_nil(infoview.get_current_infoview().info.pin.position_params)
    end)

    it('within first line of multi-line change',
    function(_)
      assert.pin_pos_changed.infoview()

      vim.api.nvim_buf_set_lines(0, 2, 4, true, {"  def test1 : Nat := test", "  "})
      assert.pin_pos_changed.infoview()
      assert.is_nil(infoview.get_current_infoview().info.pin.position_params)
    end)

    it('within last line of multi-line change',
    function(_)
      assert.pin_pos_changed.infoview()

      vim.api.nvim_buf_set_lines(0, 1, 3, true, {"  ", "  def test1 : Nat := test  "})
      assert.pin_pos_changed.infoview()
      assert.is_nil(infoview.get_current_infoview().info.pin.position_params)
    end)

    it('within change on same line',
    function(_)
      assert.pin_pos_changed.infoview()

      vim.api.nvim_buf_set_lines(0, 2, 3, true, {"def test1 : Nat :=atest"})
      assert.pin_pos_changed.infoview()
      assert.is_nil(infoview.get_current_infoview().info.pin.position_params)
    end)
  end)
end)
