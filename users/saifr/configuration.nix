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

  # CMU Typewriter Text, plus every symbol and emoji cm-unicode is missing.
  #
  # cm-unicode has none of the geometric marks, none of the Braille spinner
  # frames and no emoji at all, so each of those cells used to fall through to
  # whatever fontconfig ranked next. st advances a cell using the *primary*
  # font and then clips the drawn run to that width, so a fallback with a
  # different advance got its sides cut off -- which is why the gear, box,
  # check, star and diamond all looked mangled.
  #
  # Wide runes are the same bug with a second cause. st already implements
  # double-width cells (ATTR_WIDE, driven by wcwidth), so an emoji is given two
  # cells and clipped to 2*cw -- but no stock emoji font is built for that.
  # Noto Color Emoji advances 1.270em against the 1.05em st actually grants it,
  # and it is a 109px bitmap besides, so it is both guillotined and blurry.
  #
  # So the font answers for the whole range itself, with real outlines: narrow
  # glyphs fitted to CMU's 525/1000em cell, wide glyphs fitted to two of them.
  # Nothing is left over for a fallback to mis-measure.
  #
  # Three donor sources. DejaVu Sans supplies the fifteen narrow symbols
  # (cm-unicode has none, and it is the only installed face carrying all of them
  # that can be scaled into the cell). Noto Emoji -- monochrome, 1400+ real
  # outlines -- supplies everything else. NewCM Math supplies the twenty-four
  # mathematical operators and double-struck letters, which cm-unicode omits
  # from all 33 of its faces because the Knuth originals live in the cmmi/cmsy
  # cuts that the package does not ship; without it they fall back to DejaVu
  # Sans, a proportional face, and fifteen of the twenty-four draw wider than
  # the cell, the widest by 41%.
  #
  # The emoji pass may only add codepoints the CMU base lacks, so box drawing,
  # arrows and maths keep their original outlines byte for byte and existing
  # text cannot shift. The donors are emitted as CFF to match cm-unicode's own
  # flavour, sparing us the fontforge round-trip the Arabic merge needs.
  symbolTerminalPython = pkgs.writeText "build-cmu-symbol-terminal.py" ''
    import os
    import unicodedata

    from fontTools.fontBuilder import FontBuilder
    from fontTools.merge import Merger
    from fontTools.misc.transform import Transform
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.pens.qu2cuPen import Qu2CuPen
    from fontTools.pens.recordingPen import DecomposingRecordingPen
    from fontTools.pens.t2CharStringPen import T2CharStringPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont

    GEOMETRIC = [0x2699, 0x25A3, 0x2713, 0x2731, 0x25C8]
    BRAILLE = [0x280B, 0x2819, 0x2839, 0x2838, 0x283C,
               0x2834, 0x2826, 0x2827, 0x2807, 0x280F]
    SYMBOLS = GEOMETRIC + BRAILLE

    # Mathematical operators, relations and double-struck letters. cm-unicode
    # carries none of these in any of its 33 faces: Knuth's repertoire lives in
    # cmmi and cmsy, and the package ships neither, so every one of them fell
    # through to DejaVu Sans -- 15 of the 24 drawing wider than the cell, the
    # widest by 41%. NewCM Math is the direct successor to that missing CM cut
    # and already shares cm-unicode's 1000 upem, so nothing needs coordinate
    # conversion.
    MATH = [0x2200, 0x2203, 0x2205, 0x2208, 0x2209, 0x2227, 0x2228, 0x2229,
            0x222A, 0x2261, 0x2282, 0x2286, 0x2295, 0x2118, 0x2115, 0x211A,
            0x211D, 0x2124, 0x21D2, 0x21D4, 0x2308, 0x2309, 0x230A, 0x230B]

    # The two double arrows, which need a width cap of their own. Knuth draws
    # them 956 and 879 units across against a 525 cell -- 1.8x too wide to show
    # at natural size -- so they are the only glyphs here that are scaled down
    # by width rather than height, and the height comes along for the ride:
    # at 450 wide they land 254 tall, 24% of the cell, and read as specks next
    # to a 528-tall wedge. Letting them spend the side bearings buys back
    # height that is otherwise unreachable without distorting Knuth's 1.7:1
    # proportions or giving them two cells (which would shift the line).
    MATH_WIDE = [0x21D2, 0x21D4]

    # The floor and ceiling brackets, which need a height cap of their own.
    # Knuth draws them 242 x 1000 -- a 4.1:1 slenderness that is his, and is
    # reproduced here to under 1% -- so they are scaled by height and come out
    # narrow. At the shared 620 ceiling they measured 151 wide, 29% of the cell,
    # which read as threads next to a 450-wide wedge. Raising the ceiling for
    # these four widens them proportionally, since they stay height-bound, and
    # lands them on the 37% that DejaVu's brackets used to occupy.
    MATH_TALL = [0x2308, 0x2309, 0x230A, 0x230B]

    UPEM = 1000
    CELL = 525
    CENTRE = CELL / 2.0

    FIT_GEOMETRIC = (450, 470, 300)
    FIT_BRAILLE = (340, 340, 262)

    # Most math is width-bound like the geometric marks -- same 450, so an
    # element-of is exactly as wide as a gear -- and lands well inside the cell.
    # The two groups below are the exceptions, and each gets its own cap
    # because they are bound on the other axis.
    FIT_MATH = (450, 620, 300)
    FIT_MATH_WIDE = (490, 620, 300)
    FIT_MATH_TALL = (450, 800, 300)

    # Emoji are fitted per cell-count: a wide rune gets two cells of st's clip
    # region, so it may be drawn twice as wide as a narrow one.
    SIDE_BEARING = 45
    FIT_EMOJI_NARROW = (CELL - 2 * SIDE_BEARING, 520, 290)
    FIT_EMOJI_WIDE = (2 * CELL - 2 * SIDE_BEARING, 800, 300)


    def cell_count(codepoint):
        return 2 if unicodedata.east_asian_width(chr(codepoint)) in ("W", "F") else 1


    def build_donor(src_path, out_path, specs, tag):
        """A 1000-upem CFF font of glyphs already fitted to CMU's cell grid.

        specs: iterable of (codepoint, max_w, max_h, centre_y, ncell).
        """
        src = TTFont(src_path)
        src_glyphset = src.getGlyphSet()
        src_cmap = src.getBestCmap()

        glyph_order = [".notdef"]
        charstrings = {".notdef": T2CharStringPen(0, None).getCharString()}
        metrics = {".notdef": (CELL, 0)}
        cmap = {}
        skipped = 0

        for codepoint, max_w, max_h, centre_y, ncell in specs:
            if codepoint not in src_cmap:
                skipped += 1
                continue
            name = "symU%04X" % codepoint
            if name in charstrings:
                continue

            outline = DecomposingRecordingPen(src_glyphset)
            src_glyphset[src_cmap[codepoint]].draw(outline)

            ratio = UPEM / src["head"].unitsPerEm
            probe = BoundsPen(src_glyphset)
            outline.replay(TransformPen(probe, Transform(ratio, 0, 0, ratio, 0, 0)))
            if probe.bounds is None:
                skipped += 1
                continue
            x_min, y_min, x_max, y_max = probe.bounds

            w = x_max - x_min
            h = y_max - y_min
            if w <= 0 or h <= 0:
                skipped += 1
                continue
            scale = min(max_w / w, max_h / h)

            advance = CELL * ncell
            dx = advance / 2.0 - (x_min + x_max) / 2.0 * scale
            dy = centre_y - (y_min + y_max) / 2.0 * scale
            fit = Transform(ratio * scale, 0, 0, ratio * scale, dx, dy)

            pen = T2CharStringPen(0, None)
            outline.replay(TransformPen(
                Qu2CuPen(pen, 0.5, reverse_direction=True), fit))

            glyph_order.append(name)
            charstrings[name] = pen.getCharString()
            metrics[name] = (advance, int(round(x_min * scale + dx)))
            cmap[codepoint] = name

        font = FontBuilder(UPEM, isTTF=False)
        font.setupGlyphOrder(glyph_order)
        font.setupCharacterMap(cmap)
        font.setupCFF(
            "CMUSymbolTerminal-Donor-" + tag,
            {"FullName": "CMU Symbol Terminal Donor " + tag,
             "FamilyName": "CMU Symbol Terminal Donor " + tag,
             "Weight": "Regular"},
            charstrings, {},
        )
        font.setupHorizontalMetrics(metrics)
        font.setupHorizontalHeader(ascent=827, descent=-233)
        font.setupOS2(sTypoAscender=827, sTypoDescender=-233, usWeightClass=400)
        font.setupNameTable({
            "familyName": "CMU Symbol Terminal Donor " + tag,
            "styleName": "Regular",
            "psName": "CMUSymbolTerminalDonor-" + tag,
        })
        font.setupPost()
        font.save(out_path)
        return len(cmap), skipped


    def finish(font, family, style, weight, out_path):
        cmap = font.getBestCmap()
        hmtx = font["hmtx"]
        for codepoint, name in cmap.items():
            if name.startswith("symU"):
                hmtx.metrics[name] = (CELL * cell_count(codepoint),
                                      hmtx.metrics[name][1])

        font["post"].isFixedPitch = 1
        font["OS/2"].panose.bProportion = 9
        font["OS/2"].usWeightClass = weight

        names = font["name"]
        names.names = [
            r for r in names.names
            if r.nameID not in {1, 2, 3, 4, 6, 16, 17, 21, 22}
        ]
        values = {
            1: family, 2: style, 3: f"{family} {style}", 4: f"{family} {style}",
            6: f"CMUSymbolTerminal-{style}", 16: family, 17: style,
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
        ("Regular", "CMU_REGULAR", "DEJAVU_REGULAR", "EMOJI_REGULAR",
         "MATH_REGULAR", 400),
        ("Bold", "CMU_BOLD", "DEJAVU_BOLD", "EMOJI_BOLD", "MATH_BOLD", 700),
    ]

    for style, base_var, sym_var, emoji_var, math_var, weight in jobs:
        base_path = os.environ[base_var]
        base_cmap = set(TTFont(base_path, lazy=True).getBestCmap())

        # Only codepoints the CMU base lacks may be added. Anything CMU already
        # draws -- box drawing, arrows, maths -- keeps its original outline, so
        # existing text cannot shift.
        emoji_src = TTFont(os.environ[emoji_var], lazy=True)
        emoji_cmap = emoji_src.getBestCmap()
        specs = []
        for codepoint in sorted(emoji_cmap):
            if codepoint in base_cmap or codepoint in SYMBOLS or codepoint in MATH:
                continue
            ncell = cell_count(codepoint)
            max_w, max_h, centre_y = (FIT_EMOJI_WIDE if ncell == 2
                                      else FIT_EMOJI_NARROW)
            specs.append((codepoint, max_w, max_h, centre_y, ncell))

        sym_donor = os.path.join(temporary, f"donor-sym-{style}.otf")
        emoji_donor = os.path.join(temporary, f"donor-emoji-{style}.otf")
        math_donor = os.path.join(temporary, f"donor-math-{style}.otf")
        n_sym, _ = build_donor(
            os.environ[sym_var], sym_donor,
            [(c, *(FIT_BRAILLE if c in BRAILLE else FIT_GEOMETRIC), 1)
             for c in SYMBOLS], "sym")
        n_emoji, skipped = build_donor(
            os.environ[emoji_var], emoji_donor, specs, "emoji")
        n_math, skipped_math = build_donor(
            os.environ[math_var], math_donor,
            [(c, *(FIT_MATH_TALL if c in MATH_TALL
                   else FIT_MATH_WIDE if c in MATH_WIDE
                   else FIT_MATH), 1) for c in MATH], "math")

        merged = Merger().merge([base_path, sym_donor, emoji_donor, math_donor])
        out = os.path.join(output, f"CMUSymbolTerminal-{style}.otf")
        finish(merged, family, style, weight, out)
        print(f"{style}: +{n_sym} symbols, +{n_emoji} emoji, +{n_math} math "
              f"({skipped} empty/duplicate, {skipped_math} math skipped), "
              f"{len(merged.getBestCmap())} codepoints")

  '';

  cmuSymbolTerminal = pkgs.runCommand "cmu-symbol-terminal" {
    nativeBuildInputs = [ pythonWithFontTools ];
    CMU_REGULAR = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntt.otf";
    CMU_BOLD = "${pkgs.cm_unicode}/share/fonts/opentype/cmuntb.otf";
    DEJAVU_REGULAR = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf";
    DEJAVU_BOLD = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf";
    EMOJI_REGULAR = "${pkgs.noto-fonts-monochrome-emoji}/share/fonts/noto/NotoEmoji.ttf";
    EMOJI_BOLD = "${pkgs.noto-fonts-monochrome-emoji}/share/fonts/noto/NotoEmoji.ttf";
    MATH_REGULAR = "${pkgs.newcomputermodern}/share/fonts/opentype/public/NewCMMath-Book.otf";
    MATH_BOLD = "${pkgs.newcomputermodern}/share/fonts/opentype/public/NewCMMath-Bold.otf";
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

  environment.etc."opt/chrome/policies/managed/dark-reader.json".text = builtins.toJSON {
    ExtensionSettings.eimadpbcbfnmbkopoojfekhnkhdbieeh = {
      installation_mode = "normal_installed";
      update_url = "https://clients2.google.com/service/update2/crx";
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
