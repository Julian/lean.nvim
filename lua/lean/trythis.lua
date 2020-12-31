local trythis = {}

local function suggestions_from(diagnostic)
  return diagnostic.message:gmatch("Try this:%s*([^\n]+)%s*\n")
end

--- Swap the first suggestion from Lean with the word under the cursor.
--
--  Doesn't do any robust error checking, or allow rotating for later results
--  yet.
function trythis.swap()
  for _, diagnostic in ipairs(vim.lsp.diagnostic.get_line_diagnostics()) do
    -- luacheck: ignore
    for each in suggestions_from(diagnostic) do
      local command = "normal ciw" .. each
      vim.cmd(command)
      return
    end
  end
end

return trythis
