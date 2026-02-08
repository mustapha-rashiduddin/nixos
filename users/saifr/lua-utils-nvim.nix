{ pkgs }:

pkgs.vimUtils.buildVimPlugin rec {
  pname = "lua-utils-nvim";
  version = "1.0.2";

  src = pkgs.fetchFromGitHub {
    owner = "nvim-neorg";
    repo = "lua-utils.nvim";
    rev = "v${version}";
    # UPDATED HASH BELOW
    hash = "sha256-9ildzQEMkXKZ3LHq+khGFgRQFxlIXQclQ7QU3fcU1C4="; 
  };
}
