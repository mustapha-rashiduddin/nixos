{ pkgs }:

pkgs.st.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or []) ++ [
    (pkgs.fetchpatch {
      url = "https://st.suckless.org/patches/fullscreen/st-fullscreen-0.8.5.diff";
      hash = "sha256-52lO6K9TGrrdPljXAFo+JB39XHeNF+0ru5QzDJ+9GX8=";
    })
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

    # High-contrast color scheme (Gruvbox-inspired, brighter than defaults)
    sed -i 's/static const unsigned int defaultfg = .*/static const unsigned int defaultfg = 7;/' config.def.h
    sed -i 's/static const unsigned int defaultbg = .*/static const unsigned int defaultbg = 0;/' config.def.h
    sed -i 's/static const unsigned int defaultcs = .*/static const unsigned int defaultcs = 258;/' config.def.h

    sed -i 's/\[0\] = "#[0-9a-fA-F]*"/[0] = "#282828"/' config.def.h
    sed -i 's/\[1\] = "#[0-9a-fA-F]*"/[1] = "#cc241d"/' config.def.h
    sed -i 's/\[2\] = "#[0-9a-fA-F]*"/[2] = "#98971a"/' config.def.h
    sed -i 's/\[3\] = "#[0-9a-fA-F]*"/[3] = "#d79921"/' config.def.h
    sed -i 's/\[4\] = "#[0-9a-fA-F]*"/[4] = "#458588"/' config.def.h
    sed -i 's/\[5\] = "#[0-9a-fA-F]*"/[5] = "#b16286"/' config.def.h
    sed -i 's/\[6\] = "#[0-9a-fA-F]*"/[6] = "#689d6a"/' config.def.h
    sed -i 's/\[7\] = "#[0-9a-fA-F]*"/[7] = "#a89984"/' config.def.h
    sed -i 's/\[8\] = "#[0-9a-fA-F]*"/[8] = "#928374"/' config.def.h
    sed -i 's/\[9\] = "#[0-9a-fA-F]*"/[9] = "#fb4934"/' config.def.h
    sed -i 's/\[10\] = "#[0-9a-fA-F]*"/[10] = "#b8bb26"/' config.def.h
    sed -i 's/\[11\] = "#[0-9a-fA-F]*"/[11] = "#fabd2f"/' config.def.h
    sed -i 's/\[12\] = "#[0-9a-fA-F]*"/[12] = "#83a598"/' config.def.h
    sed -i 's/\[13\] = "#[0-9a-fA-F]*"/[13] = "#d3869b"/' config.def.h
    sed -i 's/\[14\] = "#[0-9a-fA-F]*"/[14] = "#8ec07c"/' config.def.h
    sed -i 's/\[15\] = "#[0-9a-fA-F]*"/[15] = "#ebdbb2"/' config.def.h
  '';
})
