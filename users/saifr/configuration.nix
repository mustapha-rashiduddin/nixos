{ config, pkgs, pkgs-unstable, inputs, ... }:

let
  pythonWithFontTools = pkgs.python3.withPackages (ps: [ ps.fonttools ]);
  scheherazadeScale = 1;

  mergeTerminalFonts = pkgs.writeText "merge-cmu-scheherazade.py" ''
    import os

    import fontforge
    import psMat


    arabic = fontforge.open(os.environ["SCHEHERAZADE_FONT"])
    arabic.em = 1000
    arabic.selection.all()
    arabic.transform(psMat.scale(float(os.environ["SCHEHERAZADE_SCALE"])))

    scaled_arabic = os.path.join(os.environ["TMPDIR"], "scaled-arabic.ttf")
    arabic.generate(scaled_arabic)
    arabic.close()

    faces = [
        (os.environ["CMU_REGULAR"], "Regular", "Regular", 400),
        (os.environ["CMU_BOLD"], "SemiBold", "Demi", 600),
        (os.environ["CMU_BOLD"], "Bold", "Bold", 700),
    ]
    output = os.path.join(os.environ["out"], "share", "fonts", "truetype")

    for source, style, fontforge_weight, numeric_weight in faces:
        base = fontforge.open(source)
        base.mergeFonts(scaled_arabic)
        base.familyname = "CMU Scheherazade Terminal"
        base.fontname = f"CMUScheherazadeTerminal-{style}"
        base.fullname = f"CMU Scheherazade Terminal {style}"
        base.weight = fontforge_weight
        base.os2_weight = numeric_weight
        base.generate(os.path.join(output, f"CMUScheherazadeTerminal-{style}.otf"))
        base.close()
  '';

  # Embedding Arabic in the primary face makes its scale independent of fallback selection.
  cosmicTerminalFonts = pkgs.runCommand "cosmic-terminal-fonts" {
    nativeBuildInputs = [ pkgs.fontforge pythonWithFontTools ];
    SCHEHERAZADE_SCALE = toString scheherazadeScale;
    SCHEHERAZADE_FONT = "${pkgs.scheherazade-new}/share/fonts/truetype/ScheherazadeNew-Regular.ttf";
    CMU_REGULAR = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntt.otf";
    CMU_BOLD = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntb.otf";
  } ''
    mkdir -p "$out/share/fonts/truetype"
    export HOME="$TMPDIR"

    fontforge -lang=py -script ${mergeTerminalFonts}

    python <<'PY'
    import glob
    import os
    from fontTools.ttLib import TTFont

    output = os.path.join(os.environ["out"], "share", "fonts", "truetype")

    for path in glob.glob(os.path.join(output, "CMUScheherazadeTerminal-*.otf")):
        font = TTFont(path)
        font["post"].isFixedPitch = 1
        font["OS/2"].panose.bProportion = 9
        font.save(path)
    PY
  '';
in
{
  # 1. Import Home Manager so we can use it below
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  # ================================================================
  # SYSTEM SETTINGS (Boot, Net, Time - Specific to Saifr's setup)
  # ================================================================

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.openvpn.servers.nordvpn = {
    config = "config /home/saifr/vpn/dk244.ovpn";
    authUserPass = "/etc/openvpn/creds";
    autoStart = true;
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  #services.ollama = {
  #  enable = true;
  #  package = pkgs-unstable.ollama;
  #};

  # Maintenance
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Time & Locale (Kept here as requested)
  time.timeZone = "Asia/Karachi";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # ================================================================
  # USER & DESKTOP (Saifr's Rice)
  # ================================================================

  # Keyboard Remapping
  services.keyd = {
    enable = true;
    keyboards.default = {
      settings = {
        main = {
          capslock = "layer(control)";
          escape = "capslock";
          tab = "layer(meta)";
          enter = "layer(meta)";
	  kpenter = "layer(meta)";
        };
        control = {
          j = "enter";
          h = "backspace";
          i = "tab";
          leftbrace = "escape";
        };
      };
    };
  };

# Graphical Environment
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    xkb.variant = "";
    displayManager.defaultSession = "none+i3";
    
    # Enable GDM (GNOME Display Manager) instead of LightDM
    displayManager.gdm.enable = true;
    
    # Enable GNOME
    desktopManager.gnome.enable = true;
    
    # Keep i3 enabled so you can switch between them
    windowManager.i3.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # Aesthetics
  programs.dconf.enable = true;
  console = {
    packages = with pkgs; [ terminus_font ];
    font = "ter-v32b";
  };

  fonts = {
    packages = with pkgs; [
      lmodern
      cm_unicode
      ultimate-oldschool-pc-font-pack
      xorg.fontmiscmisc      # The 9x15 font
      xorg.fontadobe100dpi   # Often needed for buttons
      xorg.fontadobe75dpi    # Often needed for labels
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      kawkab-mono-font
      amiri
      cosmicTerminalFonts
      vazir-code-font
    ];
    
    # This is the "Magic Switch" that makes NixOS link these to X11
    fontDir.enable = true;

    # This allows the "Bitmap" fonts that modern systems usually ignore
    fontconfig.allowBitmaps = true;

    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "CMU Scheherazade Terminal"
          "DejaVu Sans Mono"
        ];
      };
    };
  };

  # Shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # User Definition
  users.users.saifr = {
    isNormalUser = true;
    description = "Mustapha Rashiduddin";
    extraGroups = [ "networkmanager" "wheel" "audio" "video" "docker" ];
    packages = with pkgs; [];
  };

  # Packages & Licenses
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    maim
    wget
    curl
    git
    pciutils 
    usbutils 
    killall
    htop
  ];

  # ================================================================
  # HOME MANAGER BRIDGE (The new part)
  # ================================================================
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    
    # Pass inputs so home.nix can see neovim-nightly
    extraSpecialArgs = { inherit inputs pkgs-unstable; };
    
    # Point to the home.nix in this folder
    users.saifr = import ./home.nix;
  };

  # ================================================================
  # VIRTUALISATION & CONTAINERS
  # ================================================================
  virtualisation.docker.enable = true;

  services.openssh.enable = true;
  system.stateVersion = "25.11"; 
}
