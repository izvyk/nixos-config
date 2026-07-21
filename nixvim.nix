# This module is intended to be used as a system-level default editor. Custom user editor is to be configured via home-manager/dotfiles
{
  config,
  lib,
  pkgs,
  ...
}:

let
  nixvim = import (
    builtins.fetchGit {
      url = "https://github.com/nix-community/nixvim";
      ref = "nixos-${lib.trivial.release}";
    }
  );
in
{
  imports = [
    nixvim.nixosModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      nixfmt
      ripgrep
    ];

    opts = {
      cursorline = true;
      signcolumn = "yes";
      number = true;
      relativenumber = true;
      scrolloff = 5;

      expandtab = true;
      tabstop = 4;
      shiftwidth = 2;
      softtabstop = 0;

      undofile = true;
      swapfile = true;
      autoread = true;

      shortmess = "a";
      laststatus = 3;

      linebreak = true;
      breakindent = true;
      showbreak = "↳ ";

      list = true;
      listchars = {
        tab = "<->";
        trail = "·";
        nbsp = "␣";
        multispace = "·";
        extends = ">";
      };
    };

    globalOpts = {
      ignorecase = true;
      smartcase = true;
      smarttab = true;
      mouse = "a";
      backup = false;
    };

    diagnostic.settings = {
      virtual_text = {
        prefix = "● ";
      };
      underline = true;
      severity_sort = true;
      update_in_insert = false;
    };
    extraConfigLua = ''
    vim.diagnostic.config({
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "",
          [vim.diagnostic.severity.WARN]  = "",
          [vim.diagnostic.severity.INFO]  = "",
          [vim.diagnostic.severity.HINT]  = "󰌵",
        },
      },
    })
  '';

    colorschemes.gruvbox-material-nvim = {
      enable = true;
      settings = {
        # transparent_mode = true;
        terminal_colors = true;
        overrides = {
          # SignColumn = {
          #   bg = "#1d2021";
          # };
          # "@lsp.type.method" = {
          #   fg = "#83a598";
          # };
          # "@lsp.type.function" = {
          #   fg = "#83a598";
          # };
          # "@lsp.type.variable" = {
          #   fg = "#ebdbb2";
          # };
          # "@lsp.type.parameter" = {
          #   fg = "#d3869b";
          #   italic = true;
          # };
          # "@lsp.mod.readonly" = {
          #   bold = true;
          # };
          # NormalFloat = {
          #   bg = "#1d2021";
          # };
          # FloatBorder = {
          #   fg = "#665c54";
          #   bg = "#1d2021";
          # };
          DiagnosticVirtualTextError.bg = "NONE";
          DiagnosticVirtualTextWarn.bg = "NONE";
        };
      };
    };

    plugins = {
      treesitter = {
        enable = true;
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          nix
          bash
          lua
          vim
        ];
      };
      lsp = {
        enable = true;
        servers.nil_ls = {
          enable = true;
          settings.nil.formatting.command = [ "nixfmt" ];
        };
      };
    };

    globals.mapleader = " ";

    keymaps = [
      {
        mode = "n";
        key = "gd";
        action = "<cmd>lua vim.lsp.buf.definition()<CR>";
      }
      {
        mode = "n";
        key = "K";
        action = "<cmd>lua vim.lsp.buf.hover()<CR>";
      }
      {
        mode = "n";
        key = "<leader>f";
        action = "<cmd>lua vim.lsp.buf.format({ async = true })<CR>";
        options = {
          desc = "Format current buffer";
          silent = true;
        };
      }
    ];
  };
}
