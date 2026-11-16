# neovim.nix - System-level default editor
{ pkgs, lib, ... }:

let
  # Tools strictly scoped to Neovim's runtime execution
  neovimTools = with pkgs; [
    nil
    nixfmt
    ripgrep
  ];
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Strip unnecessary host providers for minimal latency
    withPython3 = false;
    withNodeJs = false;
    withRuby = false;

    configure = {
      # Add the tools to Neovim's PATH, then load the Lua config. Appended, so
      # a project's own versions (shell.nix via direnv) win over these.
      # The module doesn't forward wrapNeovim's extraMakeWrapperArgs, and an
      # overlay would leak into HM: the rc is the clean place for this.
      customLuaRC = ''
        vim.env.PATH = vim.env.PATH .. ":${lib.makeBinPath neovimTools}"
      ''
      + builtins.readFile ./neovim.lua;

      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [
          gruvbox-nvim # classic gruvbox, like the terminal
          snacks-nvim
          mini-nvim
          guess-indent-nvim

          (nvim-treesitter.withPlugins (
            plugins: with plugins; [
              # Core / Nix
              nix
              bash
              fish
              python
              lua
              vim
              vimdoc
              markdown # LSP hover docs
              markdown_inline

              # System admin & infrastructure
              json
              yaml
              toml
              ini

              # Diffing & Git
              diff
              gitcommit
              gitattributes
            ]
          ))
        ];
      };
    };
  };
}
