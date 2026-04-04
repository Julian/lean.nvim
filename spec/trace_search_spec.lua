local Buffer = require 'std.nvim.buffer'
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

---Check whether any leanInfoHighlighted extmarks exist in the current window's buffer.
local function has_highlighted_extmarks()
  local extmarks = Buffer:current():extmarks(-1, 0, -1, { details = true })
  return vim.iter(extmarks):any(function(mark)
    return mark[4].hl_group == 'leanInfoHighlighted'
  end)
end

describe('trace search', function()
  it(
    'highlights matching text and clears with empty query',
    helpers.clean_buffer(
      [[
        set_option trace.Meta.isDefEq true in
        example : (fun x : Nat => x) 0 = 0 := by
          rfl
      ]],
      function()
        helpers.search 'example'
        helpers.wait_for_line_diagnostics()
        helpers.wait_for_loading_pins()

        local iv = infoview.get_current_infoview()
        local lines = table.concat(iv:get_lines(), '\n')
        assert.message('Expected traces in infoview').is_truthy(lines:find 'isDefEq')

        infoview.go_to()
        helpers.feed ']t'

        helpers.with_input('Nat', function()
          iv:trace_search()
        end)

        local succeeded = vim.wait(10000, has_highlighted_extmarks)
        assert.message('Expected leanInfoHighlighted extmarks after search').is_true(succeeded)

        helpers.with_input('', function()
          iv:trace_search()
        end)

        succeeded = vim.wait(10000, function()
          return not has_highlighted_extmarks()
        end)
        assert.message('Expected no leanInfoHighlighted extmarks after clearing').is_true(succeeded)
      end
    )
  )

  it(
    'sets the search register so n/N navigate matches',
    helpers.clean_buffer(
      [[
        set_option trace.Meta.isDefEq true in
        example : (fun x : Nat => x) 0 = 0 := by
          rfl
      ]],
      function()
        helpers.search 'example'
        helpers.wait_for_line_diagnostics()
        helpers.wait_for_loading_pins()

        local iv = infoview.get_current_infoview()
        infoview.go_to()
        helpers.feed ']t'

        helpers.with_input('Nat', function()
          iv:trace_search()
        end)
        vim.wait(10000, has_highlighted_extmarks)

        vim.cmd.normal { 'gg0', bang = true }
        vim.cmd.normal { 'n', bang = true }
        assert.message('n should land on a line containing the search term').is_truthy(
          vim.api.nvim_get_current_line():find 'Nat'
        )
      end
    )
  )

  it(
    'clears the last query when the cursor moves',
    helpers.clean_buffer(
      [[
        set_option trace.Meta.isDefEq true in
        example : (fun x : Nat => x) 0 = 0 := by
          rfl
      ]],
      function()
        helpers.search 'example'
        helpers.wait_for_line_diagnostics()
        helpers.wait_for_loading_pins()

        local iv = infoview.get_current_infoview()
        infoview.go_to()
        helpers.feed ']t'

        -- Search to populate the last query.
        helpers.with_input('Nat', function()
          iv:trace_search()
        end)
        vim.wait(10000, has_highlighted_extmarks)

        -- Move the cursor in the source buffer to trigger a pin update.
        helpers.feed('<Plug>(LeanInfoviewGotoLastWindow)')
        helpers.search 'rfl'
        helpers.wait_for_loading_pins()

        -- The pre-filled query should be gone.
        infoview.go_to()
        helpers.feed ']t'
        local opts = helpers.with_input(nil, function()
          iv:trace_search()
        end)
        assert.message('Expected no pre-filled query after cursor move').is_nil(opts.default)
      end
    )
  )
end)
