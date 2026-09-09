# Shared nixpkgs customization for all hosts, as a single overlay:
# - `pkgs.unstable.*` for cherry-picking from unstable
# - wrapped agenix CLI that uses the system identity key
{
  inputs,
  ...
}:

{
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (prev) system config;
      };

      agenix = final.writeShellScriptBin "agenix" ''
        exec ${
          inputs.agenix.packages.${final.stdenv.hostPlatform.system}.default
        }/bin/agenix -i /etc/ssh/ssh_host_ed25519_key "$@"
      '';
    })
  ];
}
