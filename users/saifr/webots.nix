{ pkgs }:

let
  webots-unpacked = pkgs.stdenv.mkDerivation {
    pname = "webots-unpacked";
    version = "R2025a"; 

    src = pkgs.fetchurl {
      # THE CORRECT URL WITH THE HYPHEN!
      url = "https://github.com/cyberbotics/webots/releases/download/R2025a/webots-R2025a-x86-64.tar.bz2";
      
      # Keep the fake hash to trigger the download!
      hash = "sha256-xRJ/tCBsV6WuVSPxt/Pai2cLyJJtmuCFleE58ibzjDg=";
    };

    installPhase = ''
      mkdir -p $out/opt/webots
      cp -r * $out/opt/webots/
    '';
  };

in
pkgs.buildFHSEnv {
  name = "webots";
  
  targetPkgs = pkgs: with pkgs; [
    # Base X11 and GL libraries needed for the 3D rendering
    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXrender
    xorg.libxcb
    xorg.libXcomposite
    xorg.libxkbfile
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXfixes
    libGL
    libGLU
    mesa
    
    # UI and System dependencies
    glib
    zlib
    nss
    nspr
    dbus
    atk
    pango
    cairo
    gdk-pixbuf
    gtk3
    alsa-lib
    pulseaudio
    fontconfig
    freetype
    libxkbcommon
    wayland
    
    # Compilers & Runtimes
    gcc
    gnumake
    python3
    ffmpeg
    stdenv.cc.cc.lib
    libxcrypt-legacy

    libkrb5
    sndio
    brotli
    expat
    util-linux
    xorg.xcbutilcursor
    xorg.xcbutil
  ];

  runScript = "${webots-unpacked}/opt/webots/webots";
}
