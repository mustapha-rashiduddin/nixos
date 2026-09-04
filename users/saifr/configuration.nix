{ config, pkgs, pkgs-unstable, inputs, ... }:

let
  pythonWithFontTools = pkgs.python3.withPackages (ps: [ ps.fonttools ]);
  cosmicTerminalFontName = "CMU Amiri Terminal";
  scheherazadeScale = 1;
  amiriScale = 1;

  mkCosmicTerminalFont = {
    derivationName,
    familyName,
    filePrefix,
    arabicFont,
    arabicScale,
  }:
    let
      mergeTerminalFonts = pkgs.writeText "merge-${derivationName}.py" ''
        import os

        import fontforge


        temporary = os.environ["TMPDIR"]
        faces = [
            (os.environ["CMU_REGULAR"], "Regular"),
            (os.environ["CMU_BOLD"], "SemiBold"),
            (os.environ["CMU_BOLD"], "Bold"),
        ]

        for source, style in faces:
            base = fontforge.open(source)
            base.generate(os.path.join(temporary, f'cmu-{style}.ttf'))
            base.close()
      '';
    in
    # Embedding Arabic in the primary face makes its scale independent of fallback selection.
    pkgs.runCommand derivationName {
      nativeBuildInputs = [ pkgs.fontforge pythonWithFontTools ];
      ARABIC_FONT = arabicFont;
      ARABIC_SCALE = toString arabicScale;
      FONT_FAMILY = familyName;
      FILE_PREFIX = filePrefix;
      CMU_REGULAR = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntt.otf";
      CMU_BOLD = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntb.otf";
    } ''
      mkdir -p "$out/share/fonts/truetype"
      export HOME="$TMPDIR"

      python -m fontTools.subset "$ARABIC_FONT" \
        --output-file="$TMPDIR/arabic-subset.ttf" \
        --unicodes='U+0600-06FF,U+0750-077F,U+0870-089F,U+08A0-08FF,U+FB50-FDFF,U+FE70-FEFF,U+10E60-10E7F,U+1EE00-1EEFF' \
        --layout-features='*' \
        --glyph-names

      python <<'PY'
      import os
      from fontTools.ttLib import TTFont
      from fontTools.ttLib.scaleUpem import scale_upem

      font = TTFont(os.path.join(os.environ["TMPDIR"], "arabic-subset.ttf"))
      scale_upem(font, round(1000 * float(os.environ["ARABIC_SCALE"])))
      font["head"].unitsPerEm = 1000
      font.save(os.path.join(os.environ["TMPDIR"], "scaled-arabic.ttf"))
      PY

      fontforge -lang=py -script ${mergeTerminalFonts}

      merge_face() {
        export STYLE="$1"
        export WEIGHT="$2"
        python <<'PY'
      import os
      from fontTools.merge import Merger

      output = os.path.join(os.environ["out"], "share", "fonts", "truetype")
      temporary = os.environ["TMPDIR"]
      family = os.environ["FONT_FAMILY"]
      prefix = os.environ["FILE_PREFIX"]
      arabic = os.path.join(temporary, "scaled-arabic.ttf")
      style = os.environ["STYLE"]
      weight = int(os.environ["WEIGHT"])

      font = Merger().merge([os.path.join(temporary, f"cmu-{style}.ttf"), arabic])
      font["post"].isFixedPitch = 1
      font["OS/2"].panose.bProportion = 9
      font["OS/2"].usWeightClass = weight

      names = font["name"]
      names.names = [
          record
          for record in names.names
          if record.nameID not in {1, 2, 3, 4, 6, 16, 17, 21, 22}
      ]
      values = {
          1: family,
          2: style,
          3: f"{family} {style}",
          4: f"{family} {style}",
          6: f"{prefix}-{style}",
          16: family,
          17: style,
      }
      for platform_id, encoding_id, language_id in [(3, 1, 0x409), (1, 0, 0)]:
          for name_id, value in values.items():
              names.setName(value, name_id, platform_id, encoding_id, language_id)

      font.save(os.path.join(output, f"{prefix}-{style}.ttf"))
      PY
      }

      merge_face Regular 400
      merge_face SemiBold 600
      merge_face Bold 700
    '';

  cmuScheherazadeTerminal = mkCosmicTerminalFont {
    derivationName = "cmu-scheherazade-terminal";
    familyName = "CMU Scheherazade Terminal";
    filePrefix = "CMUScheherazadeTerminal";
    arabicFont = "${pkgs.scheherazade-new}/share/fonts/truetype/ScheherazadeNew-Regular.ttf";
    arabicScale = scheherazadeScale;
  };

  cmuAmiriTerminal = mkCosmicTerminalFont {
    derivationName = "cmu-amiri-terminal";
    familyName = "CMU Amiri Terminal";
    filePrefix = "CMUAmiriTerminal";
    arabicFont = "${pkgs.amiri}/share/fonts/truetype/Amiri-Regular.ttf";
    arabicScale = amiriScale;
  };
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

    # Keep i3 enabled so you can switch between them
    windowManager.i3.enable = true;
  };

  services.displayManager.defaultSession = "none+i3";

  # Enable GDM (GNOME Display Manager) instead of LightDM
  services.displayManager.gdm.enable = true;

  # Enable GNOME
  services.desktopManager.gnome.enable = true;

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
      cmuAmiriTerminal
      cmuScheherazadeTerminal
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
          cosmicTerminalFontName
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

  # Cargo-installed tools (notably `erd`) on PATH for EVERY shell. This is baked
  # into the set-environment block that /etc/profile sources at login, so every
  # login shell (zsh, mksh, fish, dash, bash) inherits it — no per-shell config.
  environment.sessionVariables.PATH = [ "$HOME/.cargo/bin" ];

  # ================================================================
  # HOME MANAGER BRIDGE (The new part)
  # ================================================================
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    
    # Pass inputs so home.nix can see neovim-nightly
    extraSpecialArgs = { inherit inputs pkgs-unstable cosmicTerminalFontName; };
    
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
