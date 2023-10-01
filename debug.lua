require("plenary.reload").reload_module("lsp-debug-tools")
local lsp_debug = require("lsp-debug-tools")

-- vim.lsp.set_log_level(1)

lsp_debug.start({
  expected = {},
  name = "alpine-lsp",
  cmd = { "alpine-lsp" },
  root_dir = vim.loop.cwd(),
})

-- vim.notify(vim.lsp.log.levels)
