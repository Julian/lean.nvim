local fixtures = require('tests.fixtures')

describe('lean 3', function()
  for kind, path in unpack(fixtures.lean3_project.files_it) do
    it('filetype detection ' .. kind, function()
      vim.api.nvim_command('edit ' .. path)
      assert.is.same('lean3', vim.bo.ft)
    end)
  end
end)

describe('lean 4', function()
  for kind, path in unpack(fixtures.lean_project.files_it) do
    it('filetype detection ' .. kind, function()
      vim.api.nvim_command('edit ' .. path)
      assert.is.same('lean', vim.bo.ft)
    end)
  end
end)
