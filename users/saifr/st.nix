{ pkgs }:

# COSMIC Terminal's built-in "COSMIC Dark" color set, taken from cosmic_dark()
# in cosmic-term 1.0.0 (src/terminal_theme.rs). This is what cosmic-term
# actually renders here: its config sets app_theme = "Dark" and defines no
# custom color_schemes_dark, so the builtin Dark scheme is the one in effect.
#
# cosmic_dark() deliberately leaves NamedColor::Background unset, so the
# background comes from the COSMIC theme instead: main.rs copies
# theme.cosmic().background.base into terminal::WINDOW_BG_COLOR, and for the
# Dark theme that base is the palette's gray_1, #1b1b1b. Foreground and Cursor
# are both set to BrightWhite.
let
  ansi = [
    "#1b1b1b" "#f16161" "#7cb987" "#ddc74c" "#6296be" "#be6dee" "#49bac8" "#bebebe"
    "#808080" "#ff8985" "#97d5a0" "#fae365" "#7db1da" "#d68eff" "#49bac8" "#c4c4c4"
  ];
  cursor = "#c4c4c4";
  reverseCursor = "#555555";
  defaultFg = "#c4c4c4";
  defaultBg = "#1b1b1b";

  # st's colorname[] is a flat positional array: 0-15 hold the ANSI colors and
  # 256-259 back defaultcs/defaultrcs/defaultfg/defaultbg. Rewriting the whole
  # block (rather than sed-ing entries one at a time) is what makes this
  # actually take effect: those 16 entries are positional string literals, not
  # "[N] = \"...\"" designated initializers, so per-color seds never matched.
  # Leaving st's stock defaultcs=256 / defaultfg=258 / defaultbg=259 in place
  # then resolves the cursor, foreground and background to exactly the values
  # cosmic-term uses.
  colorname = pkgs.lib.concatStringsSep "\n" (
    [ "static const char *colorname[] = {" ]
    ++ map (c: "  \"${c}\",") ansi
    ++ [
      ""
      "  [255] = 0,"
      ""
      "  /* more colors can be added after 255 to use with DefaultXX */"
      "  \"${cursor}\","
      "  \"${reverseCursor}\","
      "  \"${defaultFg}\", /* default foreground colour */"
      "  \"${defaultBg}\", /* default background colour */"
      "};"
    ]
  );
in
pkgs.st.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or []) ++ [
    (pkgs.fetchpatch {
      url = "https://st.suckless.org/patches/fullscreen/st-fullscreen-0.8.5.diff";
      hash = "sha256-52lO6K9TGrrdPljXAFo+JB39XHeNF+0ru5QzDJ+9GX8=";
    })
    # st-scrollback-0.9.2.diff (st.suckless.org) reconciled against the
    # fullscreen patch above: both insert lines into the same spots in
    # config.def.h (Shortcut array) and st.h (function decls), so the stock
    # diff won't apply. This variant targets the post-fullscreen tree.
    ./st-scrollback.diff
    (pkgs.fetchpatch {
      url = "https://st.suckless.org/patches/scrollback/st-scrollback-mouse-0.9.2.diff";
      hash = "sha256-CuNJ5FdKmAtEjwbgKeBKPJTdEfJvIdmeSAphbz0u3Uk=";
    })
    (pkgs.fetchpatch {
      # Plain touchpad/wheel scrolls history outside alternate-screen apps.
      url = "https://st.suckless.org/patches/scrollback/st-scrollback-mouse-altscreen-20220127-2c5edf2.diff";
      hash = "sha256-8oVLgbsYCfMhNEOGadb5DFajdDKPxwgf3P/4vOXfUFo=";
    })
    ./st-selection-autoscroll.diff
  ];

  postPatch = ''
    ${oldAttrs.postPatch or ""}

    # nixpkgs builds st with just -O1 (st's config.mk folds make's CFLAGS
    # into STCFLAGS). Force faster codegen; -flto on both compile and link
    # lets gcc inline across the st.c/x.c boundary. -march=native is fine
    # here: this flake only ever builds on this box.
    sed -i 's/^STCFLAGS = .*/& -O3 -march=native -pipe -fno-plt -flto/' config.mk
    sed -i 's/^STLDFLAGS = .*/& -flto/' config.mk

    # Remove the Alt+Return fullscreen binding from the fullscreen patch.
    # It collides with rainfrog's Alt+Enter query-execute keybinding.
    # (F11 fullscreen binding is kept; i3 $mod+g also toggles fullscreen.)
    sed -i '/XK_Return.*fullscreen/d' config.def.h

    # Font: PxPlus IBM VGA 8x16 bitmap font
    sed -i 's/font = ".*"/font = "PxPlus IBM VGA 8x16:pixelsize=32:antialias=false:autohint=false"/' config.def.h

    # Disable bold / fake-smearing in C code
    sed -i 's/FC_WEIGHT_BOLD/FC_WEIGHT_REGULAR/g' x.c

    # Color scheme: COSMIC Terminal's "COSMIC Dark" set, spliced in as a whole
    # so the positional colorname[] entries get replaced for real.
    cat > colorname.new <<'COLORNAME'
${colorname}
COLORNAME
    awk '
      /^static const char \*colorname\[\] = \{/ && !done {
        while ((getline line < "colorname.new") > 0) print line
        done = 1
        skip = 1
        next
      }
      skip && /^\};/ { skip = 0; next }
      skip { next }
      { print }
    ' config.def.h > config.def.h.tmp
    grep -qF -- "${builtins.head ansi}" config.def.h.tmp
    mv config.def.h.tmp config.def.h
  '';
})
