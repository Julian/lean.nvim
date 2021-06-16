local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

local function get_info_lines(infoview_info)
  return table.concat(vim.api.nvim_buf_get_lines(infoview_info.bufnr, 0, -1, true), "\n")
end

local function infoview_lsp_test(pos, expected)
    local infoview_info = infoview.open()
    vim.api.nvim_win_set_cursor(0, pos)
    infoview.update(infoview_info.bufnr)
    local result, _ = vim.wait(5000, function()
      for _, string in pairs(expected) do
        local curr = get_info_lines(infoview_info)
        if not curr:find(string) then return false end
      end
      return true
    end)
    assert.message( "expected: " .. vim.inspect(expected) ..  ", actual: " .. get_info_lines(infoview_info)
    ).is_true(result)
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
      infoview_lsp_test({3, 23}, {"⊢ ℕ"})
    end)

    it('tactic state',
    function(_)
      infoview_lsp_test({7, 10}, {"p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)
  end)

  it('lean 4', function()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
    helpers.lsp_wait()
    vim.wait(5000)

    it('term state',
    function(_)
      infoview_lsp_test({3, 23}, {"expected type", "⊢ Nat"})
    end)

    it('tactic state',
    function(_)
      infoview_lsp_test({6, 9}, {"1 goal", "p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)
  end)

end)
