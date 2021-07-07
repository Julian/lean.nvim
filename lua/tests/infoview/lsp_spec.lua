local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

local function infoview_lsp_update(pos)
  local current_infoview = infoview.get_current_infoview()
  local before = current_infoview:get_contents()
  vim.api.nvim_win_set_cursor(0, pos)
  -- wait for server pass
  local result, _ = vim.wait(10000, function()
    infoview.__update()
    -- wait for update data - will be empty if server pass incomplete
    local update_result, _ = vim.wait(500, function()
      local curr = current_infoview:get_contents()
      if curr == before or current_infoview:is_empty() then return false end
      return true
    end)
    return update_result
  end, 1000)
  assert.message("infoview text did not update in time").is_true(result)
  return current_infoview:get_contents()
end

helpers.setup {
  infoview = { enable = true },
  lsp = { enable = true },
  lsp3 = { enable = true },
}
describe('infoview', function()
  it('immediate close', function()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
    helpers.wait_for_ready_lsp()
    infoview.__update()
    infoview.get_current_infoview():close()
    vim.wait(5000, function()
      assert.is_not.has_match("Error", vim.api.nvim_exec("messages", true), nil, true)
    end)
  end)
  infoview.get_current_infoview():open()
  it('lean 3', function()
    before_each(function()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
      helpers.wait_for_ready_lsp()
    end)

    it('shows term state',
    function(_)
      local text = infoview_lsp_update({3, 23})
      assert.has_all(text, {"⊢ ℕ"})
    end)

    it('shows tactic state',
    function(_)
      local text = infoview_lsp_update({7, 10})
      assert.has_all(text, {"p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)
  end)

  it('lean 4', function()
    before_each(function()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
      helpers.wait_for_ready_lsp()
    end)

    it('shows term state',
    function(_)
      local text = infoview_lsp_update({3, 23})
      assert.has_all(text, {"expected type", "⊢ Nat"})
    end)

    it('shows tactic state',
    function(_)
      local text = infoview_lsp_update({6, 9})
      assert.has_all(text, {"1 goal", "p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)
  end)

  local win = vim.api.nvim_get_current_win()

  vim.api.nvim_command("tabnew")

  local winnew = vim.api.nvim_get_current_win()

  it('new tab', function()
    before_each(function()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
      helpers.wait_for_ready_lsp()
    end)

    it('maintains separate infoview text',
    function(_)
      local text = infoview_lsp_update({3, 23})
      assert.has_all(text, {"⊢ ℕ"})
      vim.api.nvim_set_current_win(win)
      text = infoview_lsp_update({3, 23})
      assert.has_all(text, {"expected type", "⊢ Nat"})
      vim.api.nvim_set_current_win(winnew)
    end)
  end)
end)
