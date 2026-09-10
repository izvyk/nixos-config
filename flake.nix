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
