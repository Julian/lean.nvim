=========
lean.nvim
=========

``neovim`` support for the `Lean3 Theorem Prover
<https://leanprover-community.github.io/>`_.

Prerequisites
-------------

``lean.nvim`` currently requires `neovim 0.5 HEAD / nightly
<https://github.com/neovim/neovim/releases/tag/nightly>`_.

The normal `lean.vim <https://github.com/leanprover/lean.vim>`_ is also
expected to be installed alongside to provide basic language support.

Installation
------------

Install via your favorite plugin manager. E.g., with
`vim-plug <https://github.com/junegunn/vim-plug>`_ via:

.. code-block:: vim

    Plug 'Julian/lean.nvim'

    Plug 'leanprover/lean.vim'
    Plug 'neovim/nvim-lspconfig'
    Plug 'norcalli/snippets.nvim'

Features
--------

* `snippets.nvim <https://github.com/norcalli/snippets.nvim>`_ based
  implementation of unicode character insertion

* `switch.vim <https://github.com/AndrewRadev/switch.vim/>`_ base
  definitions for Lean

* Crude implementation of "try this:" suggestion replacement


Configuration & Usage
---------------------

In e.g. your ``init.lua``:

.. code-block:: lua

    require('lean').setup{
        -- Enable unicode snippet support?
        --
        -- false to disable, otherwise a table of options described below
        snippets = {,
            extra = {
                -- Add a \wknight translation to insert ♘
                --
                -- Note that the backslash is implied, and that you may also
                -- use snippets.nvim directly to do this if so desired.
                wknight = '♘',
            },
        }
        -- Enable the Lean language server?
        --
        -- false to disable, otherwise should be a table of options to pass to
        --  `leanls`. See https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md#leanls
        -- for details though lean-language-server actually doesn't support all
        -- the options mentioned there yet.
        lsp = {
            on_attach = require('config.lsp').attached,
            cmd = {"lean-language-server", "--stdio", '--', "-M", "4096"},
        }
    }
