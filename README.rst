=========
lean.nvim
=========

``neovim`` support for the `Lean Theorem Prover
<https://leanprover.github.io/lean4/doc/>`_.

https://user-images.githubusercontent.com/329822/122589781-acbbe480-d02e-11eb-9bcd-3351b35e1a69.mp4

Prerequisites
-------------

``lean.nvim`` requires neovim 0.5 (or newer).

Installation
------------

Install via your favorite plugin manager. E.g., with
`vim-plug <https://github.com/junegunn/vim-plug>`_ via:

.. code-block:: vim

    Plug 'Julian/lean.nvim'
    Plug 'neovim/nvim-lspconfig'

    " Optional Dependencies:

    Plug 'hrsh7th/nvim-compe'  " For LSP completion
    Plug 'hrsh7th/vim-vsnip'   " For snippets
    Plug 'andrewradev/switch.vim'  " For Lean switch support

``lean.nvim`` already includes syntax highlighting and Lean filetype
support, so installing the ``lean.vim`` (i.e. non-neovim) plugin is not
required or recommended.

``lean.nvim`` supports both `Lean 3
<https://github.com/leanprover-community/lean>`_ as well as the emerging
`Lean 4 <https://github.com/leanprover/lean4>`_.

Lean 3
^^^^^^

For Lean 3 support, in addition to the instructions above, you should:

    * Install ``lean-language-server``, which can be done via e.g.:

        .. code-block:: sh

            $ npm install -g lean-language-server

Lean 4
^^^^^^

For Lean 4 support, a recent Lean 4 nightly build is recommended (one at
least from mid-June 2021).

In addition to the instructions above, there is experimental `nvim-treesitter
<https://github.com/nvim-treesitter/nvim-treesitter>`_ support being
developed in `<https://github.com/Julian/tree-sitter-lean>`_ which can
be used for enhanced indentation (TODO), text object (TODO), syntax
highlighting and querying but which is still very nascent.

If you wish to try it, it can be installed by adding e.g.:

.. code-block:: vim

    Plug 'nvim-treesitter/nvim-treesitter'
    Plug 'nvim-treesitter/nvim-treesitter-textobjects'

if you do not already have tree sitter installed.

As above, many simple syntactical things are not yet implemented (help
is of course welcome). You likely will want to flip back and forth
between it and the standard syntax highlighting via ``:TSBufDisable
highlight`` whenever encountering misparsed terms. Bug reports (to the
aforementioned repository) are also welcome.

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


    * ``<LocalLeader>i``: toggle infoview

    * ``<LocalLeader>s``: ``sorry`` insertion corresponding to the number of open goals

    * ``<LocalLeader>t``: "try this:" suggestion replacement

    * ``<LocalLeader>3``: force a buffer into Lean 3 mode

    * ``<LocalLeader>\``: show what abbreviation would produce the symbol under the cursor

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

Configuration & Usage
---------------------

In e.g. your ``init.lua``:

.. code-block:: lua

    -- If you don't already have a preferred neovim LSP setup, you may want
    -- to reference the nvim-lspconfig documentation, which can be found at:
    -- https://github.com/neovim/nvim-lspconfig#keybindings-and-completion
    -- For completeness (of showing this plugin's settings), we show
    -- a barebones LSP attach handler (which will give you Lean LSP
    -- functionality in attached buffers) here:
    local function on_attach(client, bufnr) {
        local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
        local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end
        buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', {noremap = true})
        buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', {noremap = true})
        buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')
    }

    require('lean').setup{
      -- Enable the Lean language server(s)?
      --
      -- false to disable, otherwise should be a table of options to pass to
      --  `leanls` and/or `lean3ls`.
      --
      -- See https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md#leanls for details.

      -- Lean 4
      lsp = { on_attach = on_attach }

      -- Lean 3
      lsp3 = { on_attach = on_attach },

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
        -- Change if you don't like the backslash
        -- (comma is a popular choice on French keyboards)
        leader = '\\',
      },

      -- Enable suggested mappings?
      --
      -- false by default, true to enable
      mappings = false,

      -- Infoview support
      infoview = {
        -- Enable the infoview?
        enable = true,
        -- Automatically open an infoview on entering a Lean buffer?
        autoopen = true,
        -- Set the infoview windows' widths
        width = 50,
      },

      -- Progress bar support
      progress_bars = {
        -- Enable the progress bars?
        enable = true
        -- Use a different priority for the signs
        priority = 10,
      },
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
