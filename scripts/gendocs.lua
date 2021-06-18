require('lean').setup()

local docgen = require('docgen')

local docs = {}

docs.test = function(input_dir, output_file)
  local input_files = vim.fn.globpath(input_dir, "**/[^_]*.lua", false, true)

  -- Always put init.lua first, then you can do other stuff.
  table.sort(input_files, function(a, b)
    if string.find(a, "init.lua") then
      return true
    elseif string.find(b, "init.lua") then
      return false
    else
      return a < b
    end
  end)

  local output_file_handle = io.open(output_file, "w")

  for _, input_file in ipairs(input_files) do
    docgen.write(input_file, output_file_handle)
  end

  output_file_handle:write(" vim:tw=78:ts=8:ft=help:norl:\n")
  output_file_handle:close()
  vim.cmd [[checktime]]
end

docs.test('./lua/lean/', 'doc/lean.txt')

return docs
