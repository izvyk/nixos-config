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

# neovim.nix - system-level default editor
# { pkgs, lib, ... }:
#
# let
#   # Tools scoped strictly to Neovim's runtime execution
#   neovimTools = with pkgs; [
#     nil # Nix LSP
#     nixfmt # Provides the 'nixfmt' binary
#     ripgrep # Fast grep for telescope/grep tools
#   ];
# in
# {
#   # Intercept NixOS's wrapper call to natively inject wrapperArgs
#   # nixpkgs.overlays = [
#   #   (final: prev: {
#   #     wrapNeovim =
#   #       neovim-unwrapped: config:
#   #       prev.wrapNeovim neovim-unwrapped (
#   #         config
#   #         // {
#   #           wrapperArgs = (config.wrapperArgs or [ ]) ++ [
#   #             "--prefix"
#   #             "PATH"
#   #             ":"
#   #             (lib.makeBinPath neovimTools)
#   #           ];
#   #         }
#   #       );
#   #   })
#   # ];
#
#   programs.neovim = {
#     enable = true;
#     defaultEditor = true;
#     viAlias = true;
#     vimAlias = true;
#
#     withPython3 = false;
#     withNodeJs = false;
#     withRuby = false;
#
#     configure = {
#       customLuaRC = builtins.readFile ./neovim.lua;
#
#       packages.myVimPackage = with pkgs.vimPlugins; {
#         start = [
#           gruvbox-material-nvim
#           nvim-lspconfig
#
#           (nvim-treesitter.withPlugins (
#             plugins: with plugins; [
#               nix
#               bash
#               lua
#               vim
#               vimdoc
#
#               # Version control / Diffing
#               diff
#               gitcommit
#               gitattributes
#             ]
#           ))
#         ];
#       };
#     };
#   };
# }

# neovim.nix - System-level default editor
# { pkgs, lib, ... }:
#
# let
#   # Tools strictly scoped to this editor's runtime
#   neovimTools = with pkgs; [
#     nil
#     nixfmt-rfc-style
#     ripgrep
#   ];
#
#   # Build the wrapped editor directly, bypassing the NixOS module wrapper
#   systemNeovim = pkgs.wrapNeovim pkgs.neovim-unwrapped {
#     viAlias = true;
#     vimAlias = true;
#
#     # Strip unnecessary runtime providers for instant root/admin startup
#     withPython3 = false;
#     withNodeJs = false;
#     withRuby = false;
#
#     # Natively inject CLI tools into Neovim's PATH without global overlays
#     wrapperArgs = [
#       "--prefix"
#       "PATH"
#       ":"
#       (lib.makeBinPath neovimTools)
#     ];
#
#     configure = {
#       # Read your standalone, versioned Lua file
#       customLuaRC = builtins.readFile ./neovim.lua;
#
#       packages.myVimPackage = with pkgs.vimPlugins; {
#         start = [
#           gruvbox-material-nvim
#           nvim-lspconfig
#
#           (nvim-treesitter.withPlugins (
#             plugins: with plugins; [
#               # Core / Nix
#               nix
#               bash
#               lua
#               vim
#               vimdoc
#
#               # System admin & infrastructure
#               json
#               yaml
#               toml
#               ini
#
#               # Diffing & Git
#               diff
#               gitcommit
#               gitattributes
#             ]
#           ))
#         ];
#       };
#     };
#   };
# in
# {
#   # Install the custom derivation to the system profile
#   environment.systemPackages = [ systemNeovim ];
#
#   # Explicitly configure all system administration editor fallbacks
#   environment.variables = {
#     EDITOR = "nvim";
#     VISUAL = "nvim";
#     SUDO_EDITOR = "nvim";
#     SYSTEMD_EDITOR = "nvim";
#   };
# }
