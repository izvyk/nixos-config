-- init.lua - plain, declarative-by-nature Neovim config
-- Only non-defaults; `:help vim_diff` lists what Neovim already sets.
vim.g.mapleader = " "

local opt = vim.opt
opt.cursorline = true
opt.signcolumn = "yes"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 5
opt.mouse = "a"
opt.laststatus = 3
opt.shortmess:append("aI") -- shorter messages, no intro screen
opt.confirm = true         -- ask to save instead of failing on :q
opt.splitright = true
opt.splitbelow = true

opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 2

opt.undofile = true

opt.linebreak = true
opt.breakindent = true
opt.showbreak = "↳ "

opt.list = true
opt.listchars = {
  tab = "<->",
  trail = "·",
  nbsp = "␣",
  multispace = "·",
  extends = ">",
}

opt.ignorecase = true
opt.smartcase = true

local map = vim.keymap.set

-- System clipboard
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
map({ "n", "v" }, "<leader>P", '"+P', { desc = "Paste from system clipboard" })

vim.diagnostic.config({
  virtual_text = { prefix = "● " },
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN]  = "",
      [vim.diagnostic.severity.INFO]  = "",
      [vim.diagnostic.severity.HINT]  = "󰌵",
    },
  },
})

-- Classic gruvbox, matching the terminal palette (dotfiles theme.toml).
require("gruvbox").setup({
  overrides = {
    DiagnosticVirtualTextError = { bg = "NONE" },
    DiagnosticVirtualTextWarn  = { bg = "NONE" },
  },
})
vim.cmd.colorscheme("gruvbox")

-- Treesitter: highlighting and indentation where a parser exists. Other
-- filetypes keep Vim's own indent rules.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    if pcall(vim.treesitter.start, args.buf) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- LSP. Neovim's defaults: K hover, grn rename, gra code action,
-- grr references, gri implementation, gO symbols, [d ]d diagnostics.
vim.lsp.config("nil_ls", {
  cmd = { "nil" },
  filetypes = { "nix" },
  root_markers = { "flake.nix", "default.nix", ".git" },
  settings = {
    ["nil"] = {
      formatting = { command = { "nixfmt" } },
    },
  },
})
vim.lsp.enable("nil_ls")

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local function bmap(lhs, rhs, desc)
      map("n", lhs, rhs, { buffer = args.buf, silent = true, desc = desc })
    end
    bmap("gd", vim.lsp.buf.definition, "Go to definition")
    bmap("<leader>f", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
  end,
})

-- Plugins
require("mini.icons").setup()
require("mini.surround").setup()
require("mini.pairs").setup()
require("mini.statusline").setup()
require("mini.indentscope").setup({
  symbol = "│",
  options = { try_as_border = true },
})

require("guess-indent").setup({
  override_editorconfig = false, -- .editorconfig wins
})

require("snacks").setup({
  bigfile = { enabled = true },   -- no freezes on huge logs
  quickfile = { enabled = true }, -- fast `nvim file`
  bufdelete = { enabled = true },
  scratch = { enabled = true },
  terminal = { enabled = true },
  picker = { enabled = true },    -- fuzzy finder, uses ripgrep
  words = { enabled = true },     -- highlight the word under the cursor
  scroll = { enabled = true },    -- smooth scrolling
})

map("n", "<leader><space>", function() Snacks.picker.files() end, { desc = "Find files" })
map("n", "<leader>/", function() Snacks.picker.grep() end, { desc = "Grep" })
map("n", "<leader>,", function() Snacks.picker.buffers() end, { desc = "Buffers" })
map("n", "<leader>r", function() Snacks.picker.recent() end, { desc = "Recent files" })
map("n", "<leader>h", function() Snacks.picker.help() end, { desc = "Help pages" })
map("n", "<leader>d", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete buffer" })
map("n", "<leader>.", function() Snacks.scratch() end, { desc = "Scratch buffer" })
map({ "n", "t" }, "<C-/>", function() Snacks.terminal() end, { desc = "Toggle terminal" })
