{
  description = "Saifr's NixOS Flake with Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    jujutsu.url = "github:martinvonz/jj"; # <--- ADD THIS

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {
    
    nixosConfigurations = {

      "saif-lenovo" = nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs; 
          pkgs-unstable = import nixpkgs-unstable {
            # This is strictly required by Nix flakes when doing a raw import
            system = "x86_64-linux"; 
            config.allowUnfree = true;
          };
        };
        
        modules = [
          ./hosts/saif-lenovo/configuration.nix 
          ./users/saifr/configuration.nix
        ];
      };

      "saif-thinkpad" = nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs; 
          pkgs-unstable = import nixpkgs-unstable {
            # This is strictly required by Nix flakes when doing a raw import
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        };
        
        modules = [
          ./hosts/saif-thinkpad/configuration.nix 
          ./users/saifr/configuration.nix
        ];
      };

    };
  };
}
