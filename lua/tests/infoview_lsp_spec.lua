local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

local function get_info_lines(infoview_info)
  return table.concat(vim.api.nvim_buf_get_lines(infoview_info.bufnr, 0, -1, true), "\n")
end

local function infoview_lsp_update(pos)
    local infoview_info = infoview.open()
    local before = get_info_lines(infoview_info)
    vim.api.nvim_win_set_cursor(0, pos)
    infoview.update(infoview_info.bufnr)
    local result, _ = vim.wait(5000, function()
      local curr = get_info_lines(infoview_info)
      if curr == before then return false end
      return true
    end)
    assert.message("infoview text did not update in time").is_true(result)
    return get_info_lines(infoview_info)
end

describe('infoview', function()
  helpers.setup {
    infoview = { enable = true },
    lsp = { enable = true },
    lsp3 = { enable = true },
  }

  it('lean 3', function()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
    helpers.lsp_wait()
    vim.wait(5000)

    it('term state',
    function(_)
      local text = infoview_lsp_update({3, 23})
      assert.has_all(text, {"⊢ ℕ"})
    end)

    it('tactic state',
    function(_)
      local text = infoview_lsp_update({7, 10})
      assert.has_all(text, {"p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)
  end)

  it('lean 4', function()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
    helpers.lsp_wait()
    vim.wait(5000)

    it('term state',
    function(_)
      local text = infoview_lsp_update({3, 23})
      assert.has_all(text, {"expected type", "⊢ Nat"})
    end)

    it('tactic state',
    function(_)
      local text = infoview_lsp_update({6, 9})
      assert.has_all(text, {"1 goal", "p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)
  end)

end)
