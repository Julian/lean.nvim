=========
lean.nvim
=========

``neovim`` support for the `Lean Theorem Prover <https://leanprover.github.io/lean4/doc/>`_.

https://user-images.githubusercontent.com/329822/161458848-815be138-58cd-45ed-bd94-bfc03e9f97a0.mov

Prerequisites
-------------

``lean.nvim`` supports the latest stable neovim release (currently 0.9.x) as well as the latest nightly.

(This matches what neovim itself supports upstream, which often guides what plugins end up working with).

Installation
------------

Install via your favorite plugin manager.

For example with `lazy.nvim <https://github.com/folke/lazy.nvim>`_:

.. code:: lua

    {
      'Julian/lean.nvim',
      event = { 'BufReadPre *.lean', 'BufNewFile *.lean' },

      dependencies = {
        'neovim/nvim-lspconfig',
        'nvim-lua/plenary.nvim',
        -- you also will likely want nvim-cmp or some completion engine
      },

      -- see details below for full configuration options
      opts = {
        lsp = {
          on_attach = on_attach,
        },
        mappings = true,
      }
    }

or with `vim-plug <https://github.com/junegunn/vim-plug>`_:

.. code:: vim

    Plug 'Julian/lean.nvim'
    Plug 'neovim/nvim-lspconfig'
    Plug 'nvim-lua/plenary.nvim'

    " Optional Dependencies:

    Plug 'hrsh7th/nvim-cmp'        " For LSP completion
    Plug 'hrsh7th/cmp-nvim-lsp'
    Plug 'hrsh7th/cmp-buffer'
    Plug 'hrsh7th/vim-vsnip'       " For snippets
    Plug 'andrewradev/switch.vim'  " For Lean switch support
    Plug 'tomtom/tcomment_vim'     " For commenting motions

``lean.nvim`` already includes syntax highlighting and Lean filetype support, so installing the ``lean.vim`` (i.e. non-neovim) plugin is not required or recommended.

Features
--------

* Abbreviation (unicode character) insertion (in insert mode & the command window accessible via ``q/``)

* An infoview which can show persistent goal, term & tactic state, as well as `interactive widget <https://www.youtube.com/watch?v=8NUBQEZYuis>`_ support (which should function for most widgets renderable as text)

* Hover (preview) commands:

  * ``:LeanGoal`` for showing goal state in a preview window

  * ``:LeanTermGoal`` for showing term-mode type information in a preview window

* `switch.vim <https://github.com/AndrewRadev/switch.vim/>`_ base definitions for Lean

* Simple snippets (in `VSCode-compatible format <https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax>`_, usable with e.g. `vim-vsnip <https://github.com/hrsh7th/vim-vsnip>`_)

* Lean library search path access via ``lean.current_search_path()``, suitable for use with e.g. `telescope.nvim <https://github.com/nvim-telescope/telescope.nvim/>`_ for
  live grepping.
  See the wiki for `a sample configuration <https://github.com/Julian/lean.nvim/wiki/Configuring-&-Extending#live-grep>`_.

* Simple implementations of some editing helpers, such as ``try this`` suggestion replacement

Configuration & Usage
---------------------

The short version -- after following the installation instructions above, add the below to ``~/.config/nvim/plugin/lean.lua`` or an equivalent:

.. code:: lua

    require('lean').setup{
      abbreviations = { builtin = true },
      lsp = { on_attach = on_attach },
      mappings = true,
    }

where ``on_attach`` should be your preferred LSP attach handler.

If you do not already have a preferred setup which includes LSP key mappings and (auto)completion, you may find the `fuller example here in the wiki <https://github.com/Julian/lean.nvim/wiki/Getting-Started>`_ helpful.
More detail on the full list of supported configuration options can be found below.

Semantic Highlighting
---------------------

Lean 4 supports `semantic highlighting <https://leanprover.github.io/lean4/doc/semantic_highlighting.html>`_, in which the Lean server itself will signal how to highlight terms and symbols within the editor using information available to it.

Note that even though neovim supports this highlighting, you still will want to map the semantic highlighting groups to your color scheme appropriately.
For a sample setup, see `the wiki <https://github.com/Julian/lean.nvim/wiki/Configuring-&-Extending#semantic-highlighting>`_.

Mappings
--------

If you've set ``mappings = true`` in your configuration (or have called ``lean.use_suggested_mappings()`` explicitly), a number of keys will be mapped either within Lean source files or within Infoview windows:

In Lean Files
^^^^^^^^^^^^^

The key binding ``<LocalLeader>`` below refers to a configurable prefix key within vim (and neovim).
You can check what this key is set to within neovim by running the command ``:echo maplocalleader``.
An error like ``E121: Undefined variable: maplocalleader`` indicates that it may not be set to any key.
This can be configured by putting a line in your ``~/.config/nvim/init.vim`` of the form ``let maplocalleader = "\<Space>"`` (in this example, mapping ``<LocalLeader>`` to ``<Space>``).

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

   See ``:help <LocalLeader>`` if you haven't previously interacted with the local leader key.
   Some vim users remap this key to make it easier to reach, so you may want to consider what key that means for your own keyboard layout.
   My (Julian's) ``<Leader>`` is set to ``<Space>``, and my ``<LocalLeader>`` to ``<Space><Space>``, which may be a good choice for you if you have no other preference.

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
| ``gd``                 | go-to-definition of what is under the cursor       |
+------------------------+----------------------------------------------------+
| ``gD``                 | go-to-declaration of what is under the cursor      |
+------------------------+----------------------------------------------------+
| ``gy``                 | go-to-type of what is under the cursor             |
+------------------------+----------------------------------------------------+
| ``<LocalLeader><Tab>`` | jump to the lean file associated with the current  |
|                        | infoview window                                    |
+------------------------+----------------------------------------------------+


Lean 3
------

Support for the (end of life-d) Lean 3 is also available.
In addition to the instructions above, and in addition to installing Lean 3 itself, you will need to install the separate Lean 3 ``lean-language-server``, which can be done via e.g.:

.. code:: sh

    $ npm install -g lean-language-server


Full Configuration & Settings Information
-----------------------------------------

.. code:: lua

    require('lean').setup{
      -- Enable the Lean language server(s)?
      --
      -- false to disable, otherwise should be a table of options to pass to
      --  `leanls` and/or `lean3ls`.
      --
      -- See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#leanls for details.

      -- Lean 4  (on_attach is as above, your LSP handler)
      lsp = {
        on_attach = on_attach,
        init_options = {
          -- See Lean.Lsp.InitializationOptions for details and further options.

          -- Time (in milliseconds) which must pass since latest edit until elaboration begins.
          -- Lower values may make editing feel faster at the cost of higher CPU usage.
          editDelay = 200,

          -- Whether to signal that widgets are supported.
          -- Enabled by default, as support for most widgets is implemented in lean.nvim.
          hasWidgets = true,
        }
      },

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
        -- Enable expanding of unicode abbreviations?
        enable = true,
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
        -- Should be a function that will be called anytime a new Lean file
        -- is opened. Return true to open an infoview, otherwise false.
        -- Setting this to `true` is the same as `function() return true end`,
        -- i.e. autoopen for any Lean file, or setting it to `false` is the
        -- same as `function() return false end`, i.e. never autoopen.
        autoopen = true,

        -- Set infoview windows' starting dimensions.
        -- Windows are opened horizontally or vertically depending on spacing.
        width = 50,
        height = 20,

        -- Put the infoview on the top or bottom when horizontal?
        -- top | bottom
        horizontal_position = "bottom",

        -- Always open the infoview window in a separate tabpage.
        -- Might be useful if you are using a screen reader and don't want too
        -- many dynamic updates in the terminal at the same time.
        -- Note that `height` and `width` will be ignored in this case.
        separate_tab = false,

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

      -- Redirect Lean's stderr messages somehwere (to a buffer by default)
      stderr = {
        enable = true,
        -- height of the window
        height = 5,
        -- a callback which will be called with (multi-line) stderr output
        -- e.g., use:
        --   on_lines = function(lines) vim.notify(lines) end
        -- if you want to redirect stderr to `vim.notify`.
        -- The default implementation will redirect to a dedicated stderr
        -- window.
        on_lines = nil,
      },

      -- Legacy Lean 3 support (on_attach is as above, your LSP handler)
      lsp3 = { on_attach = on_attach },

      -- mouse_events = true will simulate mouse events in the Lean 3 infoview, this is buggy at the moment
      -- so you can use the I/i keybindings to manually trigger these
      lean3 = { mouse_events = false },
    }

Other Plugins
-------------

Particularly if you're also a VSCode user, there may be other plugins you're interested in.
Below is a (hopelessly incomplete) list of a few:

* `nvim-lightbulb <https://github.com/kosayoda/nvim-lightbulb>`_ for signalling when code actions are available

* `goto-preview <https://github.com/rmagatti/goto-preview>`_ for peeking definitions (instead of jumping to them)

* `lsp-status.nvim <https://github.com/nvim-lua/lsp-status.nvim>`_ for showing LSP information in your status bar

Contributing
------------

Contributions are most welcome.
Feel free to send pull requests for anything you'd like to see, or open an issue if you'd like to discuss.

Running the tests can be done via the ``Makefile``:

.. code:: sh

    $ make test

which will execute against a minimal ``vimrc`` isolated from your own setup.

.. code:: sh

    $ TEST_FILE=lua/tests/foo_spec.lua make test

can be used to run just one specific test file, which can be faster.

Some linting and style checking is done via `pre-commit <https://pre-commit.com/#install>`_, which once installed (via the linked instructions) is run via:

.. code:: sh

    $ make lint

or on each commit automatically if you have run ``pre-commit install`` in your repository checkout.

You can also use

.. code:: sh

    $ make nvim SETUP_TABLE='{ lsp = { enable = true }, mappings = true }'

to get a normal running neovim (again isolated from your own configuration), where ``SETUP_TABLE`` is a (Lua) table like one would pass to ``lean.setup``.
