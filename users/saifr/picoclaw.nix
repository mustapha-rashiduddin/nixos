{ pkgs, pkgs-unstable }:

# OVERRIDE: We intercept the unstable builder and force it to use Go 1.26
(pkgs-unstable.buildGoModule.override { go = pkgs-unstable.go_1_26; }) rec {
  pname = "picoclaw";
  version = "main";

  src = pkgs.fetchFromGitHub {
    owner = "sipeed";
    repo = "picoclaw";
    rev = version;
    #hash = "sha256-G130IpaZMoImn73beLcuPh13wTGljWNxmE3UvR/qfa0="; 
    hash = "sha256-SnuZrdiTw3fSye+zlTXwQWPFPVkKgj+MPfXO0ZgMCBM="; 
  };

  #vendorHash = "sha256-3kDU3pbcz+2cd36/bcbdU/IXTAeJosBZ+syUQqO2bls=";
  vendorHash = "sha256-7v/2SCWgUz26m2sdDa5wrBBIqh1jqlRAepICKruFINk=";

  subPackages = [ "cmd/picoclaw" ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # FIX: Copy the 'workspace' folder to where main.go expects it
  preBuild = ''
    echo "Preparing workspace for embedding..."
    if [ -d "workspace" ]; then
      cp -r --no-preserve=mode workspace cmd/picoclaw/
    else
      # If it doesn't exist, create an empty one to satisfy the compiler
      mkdir -p cmd/picoclaw/workspace
    fi
  '';

  postInstall = ''
    wrapProgram $out/bin/picoclaw --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  '';

  meta = with pkgs.lib; {
    description = "Ultra-lightweight personal AI agent in Go";
    homepage = "https://github.com/sipeed/picoclaw";
    license = licenses.mit;
    mainProgram = "picoclaw";
  };
}
