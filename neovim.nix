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
      # Prepend the Nix store PATH to Neovim's environment, then load your clean Lua file
      customLuaRC = ''
        vim.env.PATH = "${lib.makeBinPath neovimTools}:" .. vim.env.PATH
      ''
      + builtins.readFile ./neovim.lua;

      # wrapperArgs var is not exposed, so nix-level PATH prepending is tricky
      # nixpkgs ovelrlay, while solving the problem, leaks to HM.
      # This is the only clean way I've found to prepend PATH that's scoped to neovim only

      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [
          gruvbox-material-nvim
          nvim-lspconfig

          (nvim-treesitter.withPlugins (
            plugins: with plugins; [
              # Core / Nix
              nix
              bash
              lua
              vim
              vimdoc

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
