# Contributing

Contributions are most welcome.
Feel free to send pull requests for anything you'd like to see, or open an issue if you'd like to discuss.

## Running Tests

Running the tests can be done via [`just`](https://github.com/casey/just) using the adjacent [`justfile`](justfile):

```sh
just
```

which will execute against a minimal `init.lua` isolated from your own setup.

After running the test suite once, you can save some time re-cloning dependencies by instead now running:

```sh
just retest
```

You can also run single test files by running:

```sh
just retest spec/ft_spec.lua
```

## Linting

Some linting and style checking is done via [`pre-commit`](https://pre-commit.com/#install), which once installed (via the linked instructions) is run via:

```sh
just lint
```

or on each commit automatically if you have run `pre-commit install` in your repository checkout.

## Manual Testing

You can use

```sh
just nvim '{ mappings = true }'
```

to get a normal running neovim (again isolated from your own configuration), where the provided argument is a (Lua) table like one would pass to `lean.setup`.
Any further arguments will be passed to `nvim`.
