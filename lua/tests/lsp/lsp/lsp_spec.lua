local helpers = require('tests.helpers')

local function try_lsp_req(pos, method, parser)
  vim.api.nvim_win_set_cursor(0, pos)
  local params = vim.lsp.util.make_position_params()

  local text

  local req_result
  local success, _ = vim.wait(10000, function()
    local results = vim.lsp.buf_request_sync(0, method, params)
    if not results or results[1] and results[1] == nil then return false end

    for _, result in pairs(results) do
      req_result = result.result
    end
    text = parser(req_result)
    if text and text ~= "" then return true end

    return false
  end, 1000)

  return success and text
end

describe('basic lsp', function()
  helpers.setup {
    lsp = { enable = true },
    lsp3 = { enable = true },
  }
  it('lean 3', function()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
    helpers.wait_for_ready_lsp()

    it('hover', function()
      local text = try_lsp_req({5, 20}, "textDocument/hover",
      function(result)
        if not result.contents or not type(result.contents) == "table" then return nil end
        local lines = {}
        for _, contents in ipairs(result.contents) do
          if contents.language == 'lean' then
            if not type(contents.value) == string then return nil end
            vim.list_extend(lines, {contents.value})
          end
        end
        return table.concat(lines, "\n")
      end)
      assert.message("hover request never received parseable data").is_truthy(text)
      assert.has_all(text, {"test : nat"})
    end)
    it('definition', function()
      local text = try_lsp_req({5, 20}, "textDocument/definition",
      function(result)
        if not result[1] or not type(result[1].uri) == "string" then return nil end
        return result[1].uri
      end)
      assert.message("definition request never received parseable data").is_truthy(text)
      assert.has_all(text, {"tests/fixtures/example-lean3-project/test/test1.lean"})
    end)
  end)

  it('lean 4', function()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
    helpers.wait_for_ready_lsp()

    it('hover', function()
      local text = try_lsp_req({3, 20}, "textDocument/hover",
      function(result)
        if not result.contents or not type(result.contents.value) == "string" then return nil end
        return result.contents.value
      end)
      assert.message("hover request never received parseable data").is_truthy(text)
      assert.has_all(text, {"test : Nat"})
    end)

    it('definition', function()
      local text = try_lsp_req({3, 20}, "textDocument/definition",
      function(result)
        if not result[1] or not type(result[1].targetUri) == "string" then return nil end
        return result[1].targetUri:lower()
      end)
      assert.message("definition request never received parseable data").is_truthy(text)
      -- case-insensitive because MacOS FS is case-insensitive
      assert.has_all(text, {("tests/fixtures/example-lean4-project/Test/Test1.lean"):lower()})
    end)
  end)
end)
