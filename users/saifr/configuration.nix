{ config, pkgs, pkgs-unstable, inputs, ... }:

let
  pythonWithFontTools = pkgs.python3.withPackages (ps: [ ps.fonttools ]);
  check50 = import ../../pkgs/check50.nix { inherit pkgs; };
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

  # CMU Typewriter Text, plus the handful of symbols OpenCode's TUI leans on.
  #
  # cm-unicode covers none of them, so st used to hand those cells to whatever
  # fontconfig ranked next (DejaVu Sans, a *proportional* face). st advances
  # every cell by the width of the primary font and clips each glyph run to
  # that width, so a wider proportional fallback gets its sides cut off --
  # which is why the gear, box, check, star and diamond all looked mangled.
  #
  # No single installed monospace face fixes this: DejaVu Sans Mono has the
  # five geometric marks but no Braille, and Unifont has all fifteen but draws
  # U+2699 at 0.81em and U+2731 at 0.94em, far wider than CMU's 0.525em cell.
  #
  # So we build the variant: take CMU as the base and fold the symbols in from
  # DejaVu Sans, scaling each outline down to fit CMU's cell, centring it, and
  # forcing its advance to CMU's own 525/1000em. Every glyph CMU already ships
  # is left byte-for-byte alone, so text still looks exactly as it did, and the
  # symbols can never overflow into a neighbouring cell.
  #
  # The donor is emitted as CFF to match cm-unicode's own flavour. That keeps
  # Merger on its happy path and spares us the fontforge round-trip the
  # Arabic merge above needs.
  symbolTerminalPython = pkgs.writeText "build-cmu-symbol-terminal.py" ''
    import os

    from fontTools.fontBuilder import FontBuilder
    from fontTools.merge import Merger
    from fontTools.misc.transform import Transform
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.pens.qu2cuPen import Qu2CuPen
    from fontTools.pens.recordingPen import DecomposingRecordingPen
    from fontTools.pens.t2CharStringPen import T2CharStringPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont

    # OpenCode's TUI symbols, plus the frames of the Braille thinking spinner.
    GEOMETRIC = [0x2699, 0x25A3, 0x2713, 0x2731, 0x25C8]
    BRAILLE = [0x280B, 0x2819, 0x2839, 0x2838, 0x283C,
               0x2834, 0x2826, 0x2827, 0x2807, 0x280F]
    SYMBOLS = GEOMETRIC + BRAILLE

    UPEM = 1000
    CELL = 525          # CMU Typewriter Text advance, 0.525em
    CENTRE = CELL / 2.0

    # (max ink width, max ink height, vertical centre) in font units. The
    # geometric marks are sized like a capital; the Braille cells stay small
    # and sit a touch lower, the way terminal spinners are drawn.
    FIT_GEOMETRIC = (450, 470, 300)
    FIT_BRAILLE = (340, 340, 262)


    def build_donor(src_path, out_path):
        """A 1000-upem CFF font holding just the symbols, already fitted to
        CMU's cell."""
        src = TTFont(src_path)
        src_glyphset = src.getGlyphSet()
        src_cmap = src.getBestCmap()
        ratio = UPEM / src["head"].unitsPerEm

        missing = [c for c in SYMBOLS if c not in src_cmap]
        if missing:
            raise SystemExit("donor %s lacks %s" % (
                src_path, " ".join("U+%04X" % c for c in missing)))

        glyph_order = [".notdef"]
        charstrings = {".notdef": T2CharStringPen(0, None).getCharString()}
        metrics = {".notdef": (CELL, 0)}
        cmap = {}

        for codepoint in SYMBOLS:
            name = "symU%04X" % codepoint

            # Flatten any composite first; a charstring pen cannot resolve
            # components of its own.
            outline = DecomposingRecordingPen(src_glyphset)
            src_glyphset[src_cmap[codepoint]].draw(outline)

            # Measure in CMU's units, normalising the donor's upem as we go.
            probe = BoundsPen(src_glyphset)
            outline.replay(TransformPen(probe, Transform(ratio, 0, 0, ratio, 0, 0)))
            x_min, y_min, x_max, y_max = probe.bounds

            max_w, max_h, centre_y = (FIT_BRAILLE if codepoint in BRAILLE
                                      else FIT_GEOMETRIC)
            w = x_max - x_min
            h = y_max - y_min
            if w <= 0 or h <= 0:
                raise SystemExit("U+%04X has an empty outline" % codepoint)
            scale = min(max_w / w, max_h / h)

            # Centre the fitted ink on the cell, then hold the advance at
            # CMU's own width so the terminal grid cannot drift.
            dx = CENTRE - (x_min + x_max) / 2.0 * scale
            dy = centre_y - (y_min + y_max) / 2.0 * scale
            fit = Transform(ratio * scale, 0, 0, ratio * scale, dx, dy)

            charstring_pen = T2CharStringPen(0, None)
            outline.replay(TransformPen(
                Qu2CuPen(charstring_pen, 0.5, reverse_direction=True), fit))

            glyph_order.append(name)
            charstrings[name] = charstring_pen.getCharString()
            metrics[name] = (CELL, int(round(x_min * scale + dx)))
            cmap[codepoint] = name

        font = FontBuilder(UPEM, isTTF=False)
        font.setupGlyphOrder(glyph_order)
        font.setupCharacterMap(cmap)
        font.setupCFF(
            "CMUSymbolTerminal-Donor",
            {"FullName": "CMU Symbol Terminal Donor",
             "FamilyName": "CMU Symbol Terminal Donor",
             "Weight": "Regular"},
            charstrings, {},
        )
        font.setupHorizontalMetrics(metrics)
        font.setupHorizontalHeader(ascent=827, descent=-233)
        font.setupOS2(sTypoAscender=827, sTypoDescender=-233, usWeightClass=400)
        font.setupNameTable({
            "familyName": "CMU Symbol Terminal Donor",
            "styleName": "Regular",
            "psName": "CMUSymbolTerminal-Donor",
        })
        font.setupPost()
        font.save(out_path)


    def finish(font, family, style, weight, out_path):
        # The donor already fixed every symbol's advance, but assert it here
        # too: holding the cell width open is the whole point of this font.
        hmtx = font["hmtx"]
        cmap = font.getBestCmap()
        for codepoint in SYMBOLS:
            name = cmap[codepoint]
            hmtx.metrics[name] = (CELL, hmtx.metrics[name][1])

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
            6: f"CMUSymbolTerminal-{style}",
            16: family,
            17: style,
        }
        for platform_id, encoding_id, language_id in [(3, 1, 0x409), (1, 0, 0)]:
            for name_id, value in values.items():
                names.setName(value, name_id, platform_id, encoding_id, language_id)

        font.save(out_path)


    temporary = os.environ["TMPDIR"]
    output = os.path.join(os.environ["out"], "share", "fonts", "truetype")
    os.makedirs(output, exist_ok=True)
    family = "CMU Symbol Terminal"

    jobs = [
        ("Regular", "CMU_REGULAR", "DEJAVU_REGULAR", 400),
        ("Bold", "CMU_BOLD", "DEJAVU_BOLD", 700),
    ]
    for style, base_var, donor_var, weight in jobs:
        donor = os.path.join(temporary, f"donor-{style}.otf")
        build_donor(os.environ[donor_var], donor)
        merged = Merger().merge([os.environ[base_var], donor])
        finish(merged, family, style, weight,
               os.path.join(output, f"CMUSymbolTerminal-{style}.otf"))
  '';

  cmuSymbolTerminal = pkgs.runCommand "cmu-symbol-terminal" {
    nativeBuildInputs = [ pythonWithFontTools ];
    CMU_REGULAR = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntt.otf";
    CMU_BOLD = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntb.otf";
    DEJAVU_REGULAR = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf";
    DEJAVU_BOLD = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf";
  } ''
    python ${symbolTerminalPython}
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
          #enter = "layer(meta)";
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
      cmuSymbolTerminal
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
    feh
    check50
    sops
    age
  ] ++ (with pkgs.nixos-artwork.wallpapers; [ simple-dark-gray ]);

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
