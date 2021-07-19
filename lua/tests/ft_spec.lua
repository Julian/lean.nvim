local fixtures = require('tests.fixtures')

describe('ft.detect', function()
  for kind, path in unpack(fixtures.lean_project.files_it) do
    it('detects ' .. kind .. ' lean 4 files', function()
      vim.api.nvim_command('edit ' .. path)
      assert.is.same('lean', vim.opt.filetype:get())
    end)
  end

  for kind, path in unpack(fixtures.lean3_project.files_it) do
    it('detects ' .. kind .. ' lean 3 files', function()
      vim.api.nvim_command('edit ' .. path)
      assert.is.same('lean3', vim.opt.filetype:get())
    end)
  end
end)
