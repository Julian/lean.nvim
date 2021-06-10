=========
lean.nvim
=========

``neovim`` support for the `Lean Theorem Prover
<https://leanprover-community.github.io/>`_.

Prerequisites
-------------

``lean.nvim`` currently requires `neovim 0.5 HEAD / nightly
<https://github.com/neovim/neovim/releases/tag/nightly>`_.

NOTE: ``lean.nvim`` is incompatible with `lean.vim <https://github.com/leanprover/lean.vim>`_,
as it implements its own kind of filetype detection.
You should NOT have ``lean.vim`` installed if using ``lean.nvim``.

Syntax highlighting and basic language support is included, for Lean 4 you can also
try the experimental support present via `tree-sitter-lean
<https://github.com/Julian/tree-sitter-lean>`_ by installing
`nvim-treesitter <https://github.com/nvim-treesitter/nvim-treesitter>`_

Note that many simple syntactical things are not yet implemented
(help is of course welcome), and that ``tree-sitter-lean`` is lean
4-only.

``lean.nvim`` currently supports both Lean 3 and Lean 4,
which can be used simultaneously in a single session.
However, support for Lean 3 may be removed in the future.

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

* abbreviation (unicode character) insertion, can also provide a
  `nvim-compe <https://github.com/hrsh7th/nvim-compe>`_ or
  `snippets.nvim <https://github.com/norcalli/snippets.nvim>`_
  source.

* Initial implementations of some editing helpers (note: no
  mappings are associated with these by default unless you call
  ``lean.use_suggested_mappings()`` or set ``mappings = true`` in the
  configuration)

    * ``<LocalLeader>t``: "try this:" suggestion replacement

    * ``<LocalLeader>i``: toggle infoview

    * ``<LocalLeader>pt``: set infoview per-tab mode

    * ``<LocalLeader>pw``: set infoview per-window mode

    * ``<LocalLeader>s``: ``sorry`` insertion corresponding to the number of open goals

* A basic infoview which can show persistent goal, term & tactic state

* Hover (preview) commands:

    * ``:LeanPlainGoal`` for showing goal state in a preview window

    * ``:LeanPlainTermGoal`` for showing term-mode type information
      in a preview window

* `switch.vim <https://github.com/AndrewRadev/switch.vim/>`_ base
  definitions for Lean

* Simple snippets (in `VSCode-compatible format
  <https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax>`_,
  so usable with e.g. `vim-vsnip <https://github.com/hrsh7th/vim-vsnip>`_)

You may find browsing `my own dotfiles
<https://github.com/Julian/dotfiles/tree/main/.config/nvim>`_ useful for
seeing how I use this plugin myself.

Infoview
---------------------

Infoviews can be used on a per-tab or per-window basis.
You can use the commands ``LeanInfoPerTab`` and ``LeanInfoPerWin`` to choose between them.

The "correct" way to exit a Lean source window is to use ``:q`` with your cursor in that window.
This will automatically close its corresponding infoview. Closing the source window directly
using, for example, ``CTRL-W + c``, will close the source window and leave the infoview in a "detached"
state - this is a feature, not a bug!

Configuration & Usage
---------------------

In e.g. your ``init.lua``:

.. code-block:: lua
    -- If you don't already have an existing LSP setup, you may want
    -- to reference the keybindings section of the nvim-lspconfig
    -- documentation, which can be found at:
    -- https://github.com/neovim/nvim-lspconfig#keybindings-and-completion
    on_attach = function(client, bufnr)
      local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
      local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end
      buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', {noremap = true})
      buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', {noremap = true})
      buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')
    end

    require('lean').setup{
        -- Abbreviation support
        abbreviations = {
            -- Set one of the following to true to enable abbreviations
            builtin = false, -- built-in expander
            compe = false, -- nvim-compe source
            snippets = false, -- snippets.nvim source
            -- additional abbreviations:
            extra = {
                -- Add a \wknight abbreviation to insert ♘
                --
                -- Note that the backslash is implied, and that you of
                -- course may also use a snippet engine directly to do
                -- this if so desired.
                wknight = '♘',
            },
            -- change if you don't like the backslash
            -- (comma is a popular choice on French keyboards)
            leader = '\\',
        },
        -- Enable suggested mappings?
        --
        -- false by default, true to enable
        mappings = false,
        -- Enable the infauxview?
        infoview = {
            -- Clip the infoview to a maximum width
            max_width = 79,
        },
        -- Enable the Lean3(lsp3)/Lean4(lsp) language servers?
        --
        -- false to disable, otherwise should be a table of options to pass to
        --  `leanls`. See https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md#leanls
        -- for details though lean-language-server actually doesn't support all
        -- the options mentioned there yet.
        lsp3 = {
            on_attach = on_attach,
            cmd = {"lean-language-server", "--stdio", '--', "-M", "4096"},
        },

        lsp = {
            on_attach = on_attach,
            cmd = {"lean", "--server"},
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

    * `goto-preview <https://github.com/rmagatti/goto-preview>`_ for
      peeking definitions (instead of jumping to them)

    * `lsp-status.nvim <https://github.com/nvim-lua/lsp-status.nvim>`_ for
      showing LSP information in your status bar

    * `lsp-trouble <https://github.com/folke/lsp-trouble.nvim>`_ for
      showing a grouped view of diagnostics to pair with the "infauxview"

Roadmap
-------------

Some features we plan to implement in the near future:

* Pinnable and pausable infoview messages (à la VSCode)

* Connection to true HTML infoviews (in a separate browser window)

* ... suggestions welcome!

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
