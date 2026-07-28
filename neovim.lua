-- init.lua - plain, declarative-by-nature Neovim config
vim.g.mapleader = " "

local opt = vim.opt
opt.cursorline = true
opt.signcolumn = "yes"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 5

opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 2
opt.softtabstop = 0

opt.undofile = true
opt.swapfile = true
opt.autoread = true

opt.shortmess = "a"
opt.laststatus = 3

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
opt.smarttab = true
opt.mouse = "a"
opt.backup = false

-- Yank to system clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })

-- Paste from system clipboard
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { desc = "Paste from system clipboard" })

vim.diagnostic.config({
  virtual_text = { prefix = "● " },
  underline = true,
  severity_sort = true,
  update_in_insert = false,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN]  = "",
      [vim.diagnostic.severity.INFO]  = "",
      [vim.diagnostic.severity.HINT]  = "󰌵",
    },
  },
})

require("gruvbox-material").setup({
  terminal_colors = true,
  overrides = {
    DiagnosticVirtualTextError = { bg = "NONE" },
    DiagnosticVirtualTextWarn  = { bg = "NONE" },
  },
})
vim.cmd.colorscheme("gruvbox-material")

-- Treesitter
-- natively start highlighting when a parser exists
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- Enable Treesitter-based indentation
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- LSP & Formatting
vim.lsp.config("nil_ls", {
  cmd = { "nil" },
  filetypes = { "nix" },
  root_dir = vim.fs.root(0, { "flake.nix", "default.nix", ".git" }),
  settings = {
    ["nil"] = {
      formatting = {
        command = { "nixfmt" },
      },
    },
  },
})

vim.lsp.enable("nil_ls")

-- Scope keymappings strictly to buffers with an active LSP client
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf, silent = true }
    
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
    vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover documentation" }))
    vim.keymap.set("n", "<leader>f", function()
      vim.lsp.buf.format({ async = true })
    end, vim.tbl_extend("force", opts, { desc = "Format current buffer" }))
  end,
})

-- Plugins
require("snacks").setup({
  -- Sysadmin Tools --
  bigfile = { enabled = true },   -- Prevent freezes on huge log/data files
  quickfile = { enabled = true }, -- Instant rendering when opening `nvim /path/to/file`
  bufdelete = { enabled = true }, -- Delete buffers without messing up your window layout
  scratch = { enabled = true },   -- Quick throwaway buffers for regex or notes
  terminal = { enabled = true },  -- Clean floating terminal integration

  -- Quality of Life --
  words = { enabled = true },     -- Auto-highlight identical words under your cursor
  statuscolumn = { enabled = false }, -- Keep the left gutter simple and clean
  picker = { enabled = false },   -- Set to true ONLY if you want a built-in fuzzy finder without installing Telescope/fzf

  -- Eye Candy --
  animate = { enabled = true },  -- UI scrolling animations
  dashboard = { enabled = false }, -- Skip the fancy ASCII art startup screen
  zen = { enabled = false },      -- Distraction-free mode isn't needed for config editing
  scroll = { enabled = true },   -- Smooth scrolling
});

require("mini.surround").setup()
require("mini.pairs").setup()
require("mini.statusline").setup({
  use_icons = true,
})
require("mini.indentscope").setup({
  symbol = "│",
  options = { try_as_border = true },
})

require("guess-indent").setup({
  auto_cmd = true,  -- Run automatically when opening a buffer
  override_editorconfig = false, -- Let .editorconfig files win if they exist
  -- filetype_exclude = { -- Don't guess in scratchpads or system panels
  --   "netrw",
  --   "TelescopePrompt",
  --   "oil",
  -- },
})
