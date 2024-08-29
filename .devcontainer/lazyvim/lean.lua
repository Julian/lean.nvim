return {
  {
    'Julian/lean.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'neovim/nvim-lspconfig',
    },
    opts = {
      infoview = {
        horizontal_position = 'top',
        show_processing = false,
      },
      mappings = true,
    },
  },
}
