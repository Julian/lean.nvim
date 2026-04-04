files = {
  ["demos/basic.lua"] = {
    globals = { "DEMO" },
  },
  ["lua/lean/tui.lua"] = {
    max_line_length = false,
  },
}
globals = {
  "vim",
  "lean_nvim_default_filetype",
  "describe",
  "it",
  assert = {
    fields = {
      "contents",
      "message",
      "are",
      "is",
      "is_falsy",
      "is_truthy",
    }
  },
}
