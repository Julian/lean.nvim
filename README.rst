=========
lean.nvim
=========

``neovim`` support for the `Lean Theorem Prover
<https://leanprover.github.io/lean4/doc/>`_.

https://user-images.githubusercontent.com/329822/122589781-acbbe480-d02e-11eb-9bcd-3351b35e1a69.mp4

Prerequisites
-------------

``lean.nvim`` supports neovim 0.6 or a recent neovim nightly (one
newer than December 25, 2021).

If you are on neovim 0.5.1, ensure you have ``set hidden`` in
your neovim ``init.lua`` or ``init.vim``, otherwise you may see
degraded performance from the infoview when opening and closing Lean
files. See `here <https://github.com/Julian/lean.nvim/issues/19>`_ for
details. Newer versions of neovim ``set hidden`` by default.

Installation
------------

Install via your favorite plugin manager. E.g., with
`vim-plug <https://github.com/junegunn/vim-plug>`_ via:

.. code-block:: vim

    Plug 'Julian/lean.nvim'
    Plug 'neovim/nvim-lspconfig'
    Plug 'nvim-lua/plenary.nvim'

    " Optional Dependencies:

    Plug 'hrsh7th/nvim-cmp'        " For LSP completion
    Plug 'hrsh7th/vim-vsnip'       " For snippets
    Plug 'andrewradev/switch.vim'  " For Lean switch support
    Plug 'tomtom/tcomment_vim'     " For commenting motions

``lean.nvim`` already includes syntax highlighting and Lean filetype
support, so installing the ``lean.vim`` (i.e. non-neovim) plugin is not
required or recommended.

``lean.nvim`` supports both `Lean 3
<https://github.com/leanprover-community/lean>`_ as well as the emerging
`Lean 4 <https://github.com/leanprover/lean4>`_.

Lean 3
^^^^^^

For Lean 3 support, in addition to the instructions above, you should
install ``lean-language-server``, which can be done via e.g.:

.. code-block:: sh

    $ npm install -g lean-language-server

Given that Lean 3's language server is separate from
Lean itself, also ensure you've `installed Lean 3 itself
<https://leanprover-community.github.io/get_started.html>`_.

Lean 4
^^^^^^

For Lean 4 support, a recent Lean 4 nightly build is recommended (one at
least from mid-October 2021).

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

* Abbreviation (unicode character) insertion, can also provide a
  `nvim-compe <https://github.com/hrsh7th/nvim-compe>`_ source.

* An infoview which can show persistent goal, term & tactic state,
  as well as interactive widgets in both
  `Lean 4 <https://github.com/leanprover/lean4/pull/596>`__ and
  `3 <https://www.youtube.com/watch?v=8NUBQEZYuis>`__!

* Hover (preview) commands:

  * ``:LeanGoal`` for showing goal state in a preview window

  * ``:LeanTermGoal`` for showing term-mode type information
    in a preview window

* `switch.vim <https://github.com/AndrewRadev/switch.vim/>`_ base
  definitions for Lean

* Simple snippets (in `VSCode-compatible format
  <https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax>`_,
  so usable with e.g. `vim-vsnip <https://github.com/hrsh7th/vim-vsnip>`_)

* Lean library search path access via
  ``lean.current_search_path()``, suitable for use with e.g.
  `telescope.nvim <https://github.com/nvim-telescope/telescope.nvim/>`_ for
  live grepping. See the wiki for `a sample configuration
  <https://github.com/Julian/lean.nvim/wiki/Configuring-&-Extending#live-grep>`_.

* Simple (or simplistic) implementations of some editing helpers, such as ``try
  this`` suggestion replacement

Configuration & Usage
---------------------

The short version -- after following the installation instructions above,
add the below to ``~/.config/nvim/plugin/lean.lua`` or an equivalent:

.. code-block:: lua

    require('lean').setup{
      abbreviations = { builtin = true },
      lsp = { on_attach = on_attach },
      lsp3 = { on_attach = on_attach },
      mappings = true,
    }

where ``on_attach`` should be your preferred LSP attach handler.

If you do not already have a preferred setup which includes LSP key
mappings and (auto)completion, you may find the `fuller example here in
the wiki <https://github.com/Julian/lean.nvim/wiki/Getting-Started>`_
helpful.

More detail on the full list of supported configuration options can be
found below.

Mappings
--------

If you've set ``mappings = true`` in your configuration (or have called
``lean.use_suggested_mappings()`` explicitly), a number of keys will be mapped
either within Lean source files or within Infoview windows:

In Lean Files
^^^^^^^^^^^^^

+------------------------+----------------------------------------------------+
|        Key             |                           Function                 |
+========================+====================================================+
| ``<LocalLeader>i``     | toggle the infoview open or closed                 |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>p``     | pause the current infoview                         |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>x``     | place an infoview pin                              |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>c``     | clear all current infoview pins                    |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>dx``    | place an infoview diff pin                         |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>dc``    | clear current infoview diff pin                    |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>dd``    | toggle auto diff pin mode                          |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>dt``    | toggle auto diff pin mode without clearing diff pin|
+------------------------+----------------------------------------------------+
| ``<LocalLeader>s``     | insert a ``sorry`` for each open goal              |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>t``     | replace a "try this:" suggestion under the cursor  |
+------------------------+----------------------------------------------------+
| ``<LocalLeader><Tab>`` | jump into the infoview window associated with the  |
|                        | current lean file                                  |
+------------------------+----------------------------------------------------+
| ``<LocalLeader>\\``    | show what abbreviation produces the symbol under   |
|                        | the cursor                                         |
+------------------------+----------------------------------------------------+

.. note::

   See ``:help <LocalLeader>`` if you haven't previously interacted
   with the local leader key. Some vim users remap this key to make it
   easier to reach, so you may want to consider what key that means
   for your own keyboard layout. My (Julian's) ``<Leader>`` is set to
   ``<Space>``, and my ``<LocalLeader>`` to ``<Space><Space>``, which
   may be a good choice for you if you have no other preference.

In Infoview Windows
^^^^^^^^^^^^^^^^^^^

+------------------------+----------------------------------------------------+
|        Key             |                           Function                 |
+========================+====================================================+
| ``<CR>``               | click a widget or interactive area of the infoview |
+------------------------+----------------------------------------------------+
| ``K``                  | click a widget or interactive area of the infoview |
+------------------------+----------------------------------------------------+
| ``<Tab>``              | jump into a tooltip (from a widget click)          |
+------------------------+----------------------------------------------------+
| ``<Shift-Tab>``        | jump out of a tooltip and back to its parent       |
+------------------------+----------------------------------------------------+
| ``<Esc>``              | clear all open tooltips                            |
+------------------------+----------------------------------------------------+
| ``J``                  | jump into a tooltip (from a widget click)          |
+------------------------+----------------------------------------------------+
| ``C``                  | clear all open tooltips                            |
+------------------------+----------------------------------------------------+
| ``I``                  | mouse-enter what is under the cursor               |
+------------------------+----------------------------------------------------+
| ``i``                  | mouse-leave what is under the cursor               |
+------------------------+----------------------------------------------------+
| ``<LocalLeader><Tab>`` | jump to the lean file associated with the current  |
|                        | infoview window                                    |
+------------------------+----------------------------------------------------+


Full Configuration & Settings Information
-----------------------------------------

.. code-block:: lua

    require('lean').setup{
      -- Enable the Lean language server(s)?
      --
      -- false to disable, otherwise should be a table of options to pass to
      --  `leanls` and/or `lean3ls`.
      --
      -- See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#leanls for details.

      -- Lean 4  (on_attach is as above, your LSP handler)
      lsp = { on_attach = on_attach },

      -- Lean 3  (on_attach is as above, your LSP handler)
      lsp3 = { on_attach = on_attach },

      -- mouse_events = true will simulate mouse events in the Lean 3 infoview, this is buggy at the moment
      -- so you can use the I/i keybindings to manually trigger these
      lean3 = { mouse_events = false },

      ft = {
        -- What filetype should be associated with standalone Lean files?
        -- Can be set to "lean3" if you prefer that default.
        -- Having a leanpkg.toml or lean-toolchain file should always mean
        -- autodetection works correctly.
        default = "lean",

        -- A list of patterns which will be used to protect any matching
        -- Lean file paths from being accidentally modified (by marking the
        -- buffer as `nomodifiable`).
        nomodifiable = {
            -- by default, this list includes the Lean standard libraries,
            -- as well as files within dependency directories (e.g. `_target`)
            -- Set this to an empty table to disable.
        }
      },

      -- Abbreviation support
      abbreviations = {
        -- Set one of the following to true to enable abbreviations
        builtin = false, -- built-in expander
        compe = false, -- nvim-compe source
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
        -- Automatically open an infoview on entering a Lean buffer?
        autoopen = true,

        -- Set infoview windows' starting dimensions.
        -- Windows are opened horizontally or vertically depending on spacing.
        width = 50,
        height = 20,

        -- Show indicators for pin locations when entering an infoview window?
        -- always | never | auto (= only when there are multiple pins)
        indicators = "auto",
      },

      -- Progress bar support
      progress_bars = {
        -- Enable the progress bars?
        enable = true,
        -- Use a different priority for the signs
        priority = 10,
      },

      -- Print Lean's stderr messages to a vim buffer
      stderr = { enable = true },
    }

Other Plugins
-------------

Particularly if you're also a VSCode user, there may be other plugins
you're interested in. Below is a (hopelessly incomplete) list of a few:

* `nvim-lightbulb <https://github.com/kosayoda/nvim-lightbulb>`_ for
  signalling when code actions are available

* `goto-preview <https://github.com/rmagatti/goto-preview>`_ for
  peeking definitions (instead of jumping to them)

* `lsp-status.nvim <https://github.com/nvim-lua/lsp-status.nvim>`_ for
  showing LSP information in your status bar

* `lsp-trouble <https://github.com/folke/lsp-trouble.nvim>`_ for
  showing a grouped view of diagnostics to pair with the "infauxview"

Contributing
------------

Contributions are most welcome. Feel free to send pull requests for anything
you'd like to see, or open an issue if you'd like to discuss.

Running the tests can be done via the ``Makefile``:

.. code-block:: sh

    $ make test

which will execute against a minimal ``vimrc`` isolated from your own setup.

.. code-block:: sh

    $ TEST_FILE=lua/tests/foo_spec.lua make test

can be used to run just one specific test file, which can be faster.

Some linting and style checking is done via `pre-commit
<https://pre-commit.com/#install>`_, which once installed (via the linked
instructions) can be run via:

.. code-block:: sh

    $ make lint

or on each commit automatically by running ``pre-commit install`` in your
repository checkout.

You can also use

.. code-block:: sh

    $ make nvim SETUP_TABLE='{ lsp3 = { enable = true }, mappings = true }'

to get a normal running neovim (again isolated from your own configuration),
where ``SETUP_TABLE`` is a (Lua) table like one would pass to ``lean.setup``.
