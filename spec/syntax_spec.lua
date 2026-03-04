local Window = require 'std.nvim.window'
local clean_buffer = require('spec.helpers').clean_buffer

vim.o.debug = 'throw'
vim.o.report = 9999

describe('syntax', function()
  describe('string interpolation', function()
    it(
      'is highlighted only in s! strings',
      clean_buffer(
        [[
        def example1 := s!"hello {x}"
        def example2 := "hello {x}"
      ]],
        function()
          local win = Window:current()
          win:set_cursor { 1, 25 }

          local syn1 = vim.fn.synID(vim.fn.line '.', vim.fn.col '.', true)
          assert.matches(
            'nterpolation',
            vim.fn.synIDattr(syn1, 'name'),
            'interpolation highlighted in s! string'
          )

          win:set_cursor { 2, 18 }

          local syn2 = vim.fn.synID(vim.fn.line '.', vim.fn.col '.', true)
          assert.not_matches(
            'nterpolation',
            vim.fn.synIDattr(syn2, 'name'),
            'no interpolation highlighting in regular string'
          )
        end
      )
    )
  end)
end)
