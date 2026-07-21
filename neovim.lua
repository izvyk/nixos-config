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
-- Extend the default nil_ls configuration provided by nvim-lspconfig
vim.lsp.config("nil_ls", {
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
