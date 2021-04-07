=========
lean.nvim
=========

``neovim`` support for the `Lean Theorem Prover
<https://leanprover-community.github.io/>`_.

Prerequisites
-------------

``lean.nvim`` currently requires `neovim 0.5 HEAD / nightly
<https://github.com/neovim/neovim/releases/tag/nightly>`_.

For syntax highlighting and basic language support, you should either:

    * Install the normal `lean.vim <https://github.com/leanprover/lean.vim>`_.

    * or try the experimental support present via `tree-sitter-lean
      <https://github.com/Julian/tree-sitter-lean>`_ by installing
      `nvim-treesitter <https://github.com/nvim-treesitter/nvim-treesitter>`_

       Note that many simple syntactical things are not yet implemented
       (help is of course welcome), and that ``tree-sitter-lean`` is lean
       4-only.

Installation
------------

Install via your favorite plugin manager. E.g., with
`vim-plug <https://github.com/junegunn/vim-plug>`_ via:

.. code-block:: vim

    Plug 'Julian/lean.nvim'

    Plug 'hrsh7th/nvim-compe'
    Plug 'leanprover/lean.vim'
    Plug 'neovim/nvim-lspconfig'

For LSP support in Lean 3, you also first need to install
``lean-language-server``, which can be done via e.g.:

.. code-block:: sh

    $ npm install -g lean-language-server

In the future, support may be added for automatically installing it as
part of this plugin.

Features
--------

* abbreviation (unicode character) insertion using either
  `nvim-compe <https://github.com/hrsh7th/nvim-compe>`_ or
  `snippets.nvim <https://github.com/norcalli/snippets.nvim>`_

* `switch.vim <https://github.com/AndrewRadev/switch.vim/>`_ base
  definitions for Lean

* Initial implementations of some editing helpers (note: no
  mappings are associated with these by default unless you call
  ``lean.use_suggested_mappings()`` or set ``mappings = true`` in the
  configuration)

    * "try this:" suggestion replacement

    * ``sorry`` insertion corresponding to the number of open goals

* LSP Commands

    * ``:LeanPlainGoal`` for showing the tactic state (good for binding to
      ``CursorHold``, and can be customized via
      ``vim.lsp.handlers["$/lean/plainGoal"]``)

* Simple snippets (in `VSCode-compatible format
  <https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax>`_,
  so usable with e.g. `vim-vsnip <https://github.com/hrsh7th/vim-vsnip>`_)


Configuration & Usage
---------------------

In e.g. your ``init.lua``:

.. code-block:: lua

    require('lean').setup{
        -- Enable abbreviation support?
        --
        -- false to disable, otherwise a table of options described below
        abbreviations = {,
            extra = {
                -- Add a \wknight abbreviation to insert ♘
                --
                -- Note that the backslash is implied, and that you of
                -- course may also use a snippet engine directly to do
                -- this if so desired.
                wknight = '♘',
            },
        }
        -- Enable suggested mappings?
        --
        -- false by default, true to enable
        mappings = false,
        -- Enable the Lean language server?
        --
        -- false to disable, otherwise should be a table of options to pass to
        --  `leanls`. See https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md#leanls
        -- for details though lean-language-server actually doesn't support all
        -- the options mentioned there yet.
        lsp = {
            on_attach = function(client, bufnr)
                -- See https://github.com/neovim/nvim-lspconfig#keybindings-and-completion
                -- for detailed examples of what you may want to do here.
                --
                -- Mapping a key (typically K) to `vim.lsp.buf.hover()`
                -- is highly recommended for Lean, since the hover LSP command
                -- is where you'll see the current goal state.
                --
                -- You may furthermore want to add an `autocmd` to run it on
                -- `CursorHoldI`, which will show the goal state any time the
                -- cursor is unmoved in insert mode.
                --
                -- In the future, this plugin may offer a recommended "complete
                -- setup" for easy enabling of the above.
                local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
                local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end
                buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', {noremap = true})
                buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', {noremap = true})
                buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')
            end,
            cmd = {"lean-language-server", "--stdio", '--', "-M", "4096"},
        }
    }

If you're using an ``init.vim``-only configuration setup, simply surround the
above with:

.. code-block:: vim

    lua <<EOF
        require('lean').setup{
            ...
        }
    EOF

Other Plugins
-------------

Particularly if you're also a VSCode user, there may be other plugins
you're interested in. Below is a (hopelessly incomplete) list of a few:

    * `nvim-lightbulb <https://github.com/kosayoda/nvim-lightbulb>`_ for
      signalling when code actions are available

    * `lspsaga.nvim <https://github.com/glepnir/lspsaga.nvim>`_ for an
      extended LSP experience on top of the builtin one

    * `lsp-status.nvim <https://github.com/nvim-lua/lsp-status.nvim>`_ for
      showing LSP information in your status bar

Contributing
------------

Contributions are most welcome, as is just letting me know you use this at this
point :)

Running the tests can be done via the ``Makefile``:

.. code-block:: sh

    $ make test

which will execute against a minimal ``vimrc`` isolated from your own setup.

Some linting and style checking is done via `pre-commit
<https://pre-commit.com/#install>`_, which once installed (via the linked
instructions) can be run via:

.. code-block:: sh

    $ make lint

or on each commit automatically by running ``pre-commit install`` in your
repository checkout.
