local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('infoview highlighting', function()
  it(
    'highlights the innermost subexpression',
    helpers.clean_buffer('example : 2 + 2 = 4 := by ', function()
      helpers.move_cursor { to = { 1, 25 } }
      assert.infoview_contents.are [[
          ⊢ 2 + 2 = 4

          ▼ 1:24-1:26: error:
          unsolved goals
          ⊢ 2 + 2 = 4
        ]]

      infoview.go_to()
      assert.current_cursor.is { 1, 4 }

      assert.highlighted_text.is '2'

      helpers.move_cursor { to = { 1, 5 } }
      assert.highlighted_text.is '2 + 2'

      helpers.move_cursor { to = { 1, 8 } }
      assert.highlighted_text.is '2'

      helpers.move_cursor { to = { 1, 9 } }
      assert.highlighted_text.is '2 + 2 = 4'
    end)
  )
end)
