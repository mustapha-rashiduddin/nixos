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
    rev = "a7dca75c04ebc57c99a9786051729b55fdd72a2f";
    hash = "sha256-TrWsqoFvARUBoSLLm0mHdidIOCzNldBun8U7BsMUHVI=";
  };

  cargoHash = "sha256-xmsgsSoJ8INa0BE6LpebBSBTXMmjGmqkCPmEZSxYDP0=";

  doCheck = false;
}
