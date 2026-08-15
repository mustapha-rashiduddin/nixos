{ pkgs }:

let
  # Use the latest Rust compiler from the overlay
  customRustPlatform = pkgs.makeRustPlatform {
    cargo = pkgs.rust-bin.stable.latest.default;
    rustc = pkgs.rust-bin.stable.latest.default;
  };
in
customRustPlatform.buildRustPackage rec {
  pname = "fresh-ide";
  version = "master";

  src = pkgs.fetchFromGitHub {
    owner = "sinelaw";
    repo = "fresh";
    rev = "master";
    hash = "sha256-iHmgrWWlVOgemFXdj2V0eNOgH4G5SUJYzkV68pumYZc="; 
  };

  cargoHash = "sha256-dHVyVbj/3GrAYZkCZTod+k7zdvUt100w+KpxfyIgWAs=";

  doCheck = false;
}
