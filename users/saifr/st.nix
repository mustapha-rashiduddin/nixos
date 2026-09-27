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

    # Font: st's "COSMIC Terminal" font, i.e. whatever
    # ~/.config/cosmic/com.system76.CosmicTerm/v1 currently holds.
    #
    #   font_name         = "CMU Amiri Terminal"
    #   font_weight       = 600   (SemiBold)
    #   bold_font_weight  = 700
    #   dim_font_weight   = 600
    #   font_size         = 14    (config.rs default; no font_size file
    #                               exists, so cosmic-term never had it
    #                               changed, and zoom_adj is 0)
    #
    # Amiri is dropped for CMU Typewriter Text. Size reasoning, measured off
    # the font tables (upem 1000 for both):
    #
    #   CMU Amiri Terminal   hhea asc+desc = 1.758 em, cap height 0.646 em
    #   CMU Typewriter Text  hhea asc+desc = 1.096 em, cap height 0.611 em
    #
    # fontconfig's built-in DPI is 75, not 96, so size=N pt gives an em of
    # N*75/72 px. cosmic-term's font_size=14 on Amiri works out to a 14px em
    # and a 9.04px cap height, so CMU Typewriter Text at size=14 (14.58px em,
    # 8.91px cap) does land within 2% of cosmic-term's nominal size. That is
    # still not what "bigger" looks like, and because Typewriter Text carries
    # so much less asc+desc than Amiri its rows come out at 1.096 em against
    # cosmic's hardcoded ceil(font_size * 1.4) = 20px, which reads cramped.
    #
    # size=17.5 gives an 18.23px em and an 11.14px cap height, 23% larger
    # glyphs than cosmic-term, and its rows land on ceil(1.096 * 18.23) =
    # 20px, which is cosmic-term's row height exactly. One number gets both.
    #
    # Tune it live before rebuilding: ctrl+shift+Prior / ctrl+shift+Next step
    # the pixel size by 1, ctrl+shift+Home resets back to this value.
    #
    # weight must be fontconfig's *named* constant, never a bare number.
    # fontconfig scores weight with getWeightDistance(), which only knows the
    # names in its internal weights[] table, so "weight=600" runs that lookup
    # off the end of the table. fc-match confirms weight=200..800 all resolve
    # to Bold for every family tried, CMU Amiri Terminal included, even though
    # it does ship a real SemiBold. "weight=semibold" is the spelling that
    # actually selects SemiBold. CMU Symbol Terminal has no SemiBold cut
    # (Regular/Bold only) so it lands on Bold, the closest face to
    # CMU Amiri Terminal's SemiBold.ttf.
    #
    # antialias=false:autohint=false came with the old PxPlus bitmap font and
    # is dropped, so this scalable OTF is hinted and antialiased the way
    # cosmic-term's swash rasterizer renders it.
    # "CMU Symbol Terminal" is cm-unicode's own CMU Typewriter Text with the
    # TUI symbols folded in, built in configuration.nix. cm-unicode covers
    # none of them, so they used to fall through to fontconfig's next pick --
    # DejaVu Sans, a proportional face wider than st's 12px cell. st advances
    # every cell by the primary font's width and clips each glyph run to it,
    # so the gear, box, check, star, diamond and the Braille spinner frames all
    # came out with their sides shaved off. The new family carries those
    # glyphs itself, each scaled into CMU's cell with a 525/1000em advance, so
    # nothing can overflow a cell and no fallback is consulted for them.
    sed -i 's/font = ".*"/font = "CMU Symbol Terminal:size=17.5:weight=semibold"/' config.def.h
    grep -q 'font = "CMU Symbol Terminal:size=17.5:weight=semibold"' config.def.h

    # dc.bfont and dc.ibfont keep stock FC_WEIGHT_BOLD, which is the 700
    # that cosmic-term's bold_font_weight = 700 asks for. The previous
    # FC_WEIGHT_BOLD -> FC_WEIGHT_REGULAR sed existed to kill fake-bold on
    # top of a Regular face; with the regular face now resolving to Bold it
    # would invert things and render bold text *lighter* than normal text.
    # (dim_font_weight = 600 has no st equivalent: st has no ATTR_DIM.)

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
