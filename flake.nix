{
  description = "NixOS multi-host setup";

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Weekly prebuilt nix-index database: building it locally takes long and a
    # lot of RAM.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Secure Boot for buratino. Not in nixpkgs; pinned to a release tag.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Declarative KVM guests (tortila: mini-lab).
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    godbus-monitor = {
      url = "github:izvyk/godbus-monitor";
      flake = false;
    };
  };

  outputs = { self, nixpkgs-stable, nixpkgs-unstable, ... }@inputs: {
    nixosConfigurations = {
      buratino = nixpkgs-stable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/buratino ];
      };

      tortila = nixpkgs-stable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/tortila ];
      };
    };
  };
}
