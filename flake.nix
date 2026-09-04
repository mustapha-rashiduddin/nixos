{
  description = "Saifr's NixOS Flake with Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    jujutsu.url = "github:martinvonz/jj"; # <--- ADD THIS

    syntaqlite.url = "github:LalitMaganti/syntaqlite/v0.9.0";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    sops-nix.url = "github:Mic92/sops-nix";

    # ADDED: Rust overlay to get the latest compiler
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  # ADDED rust-overlay to outputs
  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, rust-overlay, ... }@inputs: {
    
    nixosConfigurations = {

      "saif-lenovo" = nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs; 
          pkgs-unstable = import nixpkgs-unstable {
            system = "x86_64-linux"; 
            config.allowUnfree = true;
          };
        };
        
        modules = [
          # ADDED: Inject the rust overlay
          ({ pkgs, ... }: { nixpkgs.overlays = [ rust-overlay.overlays.default ]; })
          ./hosts/saif-lenovo/configuration.nix 
          ./users/saifr/configuration.nix
        ];
      };

      "saif-thinkpad" = nixpkgs.lib.nixosSystem {
        specialArgs = { 
          inherit inputs; 
          pkgs-unstable = import nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        };
        
        modules = [
          # ADDED: Inject the rust overlay
          ({ pkgs, ... }: { nixpkgs.overlays = [ rust-overlay.overlays.default ]; })
          ./hosts/saif-thinkpad/configuration.nix 
          ./users/saifr/configuration.nix
        ];
      };

    };
  };
}
