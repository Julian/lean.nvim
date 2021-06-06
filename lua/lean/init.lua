local lean = {
  lsp = require('lean.lsp'),
  abbreviations = require('lean.abbreviations'),
}

function lean.setup(opts)
  opts = opts or {}


  local abbreviations = opts.abbreviations or {}
  if abbreviations.enable ~= false then lean.abbreviations.enable(abbreviations) end

  local treesitter = opts.treesitter or {}
  if treesitter.enable ~= false then require('lean.treesitter').enable(treesitter) end

  local infoview = opts.infoview or {}
  if infoview.enable ~= false then
      require('lean.infoview').enable(infoview)
      opts.commands = vim.tbl_extend("keep", opts.commands or {}, {
          LeanInfoPerTab = {
            function ()
              require('lean.infoview').set_pertab()
            end;
            description = "Set one infoview per tab."
          };
          LeanInfoPerWin = {
            function ()
              require('lean.infoview').set_perwindow()
            end;
            description = "Set one infoview per window."
          };
        })
  end

  local function set_cmds(lsp_opts)
    lsp_opts.commands = vim.tbl_extend("keep", lsp_opts.commands or {}, opts.commands or {})
  end

  local lsp3 = opts.lsp3 or {}
  if lsp3.enable ~= false then set_cmds(lsp3) lean.lsp.enable3(lsp3) end

  local lsp = opts.lsp or {}
  if lsp.enable ~= false then set_cmds(lsp) lean.lsp.enable(lsp) end

  if opts.mappings == true then
    vim.api.nvim_exec(string.format([[
      autocmd FileType lean lua require'lean.mappings'.use_suggested_mappings()
      autocmd FileType lean3 lua require'lean.mappings'.use_suggested_mappings()
    ]]), false)
  end
end

return lean
