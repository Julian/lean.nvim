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
    Plug 'nvim-lua/completion-nvim'

For LSP support in Lean 3, you also first need to install
``lean-language-server``, which can be done via e.g.:

.. code-block:: sh

    $ npm install -g lean-language-server

In the future, support may be added for automatically installing it as
part of this plugin.

Features
--------

* `snippets.nvim <https://github.com/norcalli/snippets.nvim>`_ based
  implementation of unicode character insertion

* `switch.vim <https://github.com/AndrewRadev/switch.vim/>`_ base
  definitions for Lean

* Initial implementations of some editing helpers (note: no mappings are
  associated with these by default)

    * "try this:" suggestion replacement

    * ``sorry`` insertion corresponding to the number of open goals


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
                -- Add a \wknight abbreviation to insert ♘
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

If you're using an ``init.vim``-only configuration setup, simply surround the
above with:

.. code-block:: vim

    lua <<EOF
        require('lean').setup{
            ...
        }
    EOF

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
