local harness = require('inanis')
local opts = {
  minimal_init = './scripts/minimal_init.lua',
  sequential = vim.env.TEST_SEQUENTIAL ~= nil,
}

for _, test_file in ipairs(arg) do
  if vim.fn.isdirectory(test_file) == 1 then
    harness.test_directory(test_file, opts)
  else
    harness.test_file(test_file, opts)
  end
end
