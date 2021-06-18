local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

local function infoview_lsp_update(pos)
    local before = infoview.get_info_lines()
    vim.api.nvim_win_set_cursor(0, pos)
    -- wait for server pass
    local result, _ = vim.wait(10000, function()
      infoview.update(infoview.open().bufnr)
      -- wait for update data - will be empty if server pass incomplete
      local update_result, _ = vim.wait(500, function()
        local curr = infoview.get_info_lines()
        if curr == before or curr == "" then return false end
        return true
      end)
      return update_result
    end, 1000)
    assert.message("infoview text did not update in time").is_true(result)
    return infoview.get_info_lines()
end

describe('infoview', function()
  helpers.setup {
    infoview = { enable = true },
    lsp = { enable = true },
    lsp3 = { enable = true },
  }

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

end)
