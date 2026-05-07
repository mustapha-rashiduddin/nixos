{ config, pkgs, pkgs-unstable, inputs, ... }:

let 
  #erd-go = import ./erd-go.nix { inherit pkgs; };
  #qwen-agent = import ./qwen-agent.nix { inherit pkgs; };
  #lua-utils-nvim = import ./lua-utils-nvim.nix { inherit pkgs; };
  #pathlib-nvim = import ./pathlib-nvim.nix { inherit pkgs; };
  #picoclaw = import ./picoclaw.nix { inherit pkgs pkgs-unstable; };
  #nanobot = import ./nanobot.nix { inherit pkgs; };   # <-- add this
in
{
  # THIS MUST BE HERE AT THE TOP LEVEL
  home.stateVersion = "25.11";

  #home.sessionVariables = {
  #  EDITOR = "nvim";
  #};

  home.shellAliases = {
    theme = "~/.config/config-manager/theme.sh";
  };

  #programs.gemini-cli = {
  #  enable = true;
  #};

  home.packages = with pkgs; [
    #((vim-full.override {
    #features = "tiny";
    #guiSupport = false;
    #luaSupport = false;
    #pythonSupport = false;
    #rubySupport = false;
    #perlSupport = false;
    #tclSupport = false;
    #nlsSupport = false;
    #}).overrideAttrs (oldAttrs: {
    ## This deletes the bloated NixOS default vimrc after compilation!
    #postInstall = (oldAttrs.postInstall or "") + ''
    #  rm -f $out/share/vim/vimrc
    #'';
    #}))
   wgnord
   brave

      ((vim-full.override {
    features = "normal";
    guiSupport = false;
    luaSupport = false;
    pythonSupport = false;
    rubySupport = false;
    perlSupport = false;
    tclSupport = false;
    nlsSupport = false;
  }).overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      rm -f $out/share/vim/vimrc
      
      cat << 'EOF' > $out/share/vim/vimrc
vim9script

if has("autocmd")
    autocmd BufReadPost * {
        if line("'\"") > 1 && line("'\"") <= line("$")
            execute "normal! g`\""
        endif
    }
endif
EOF
    '';
  }))
xclip # (Optional: for tiny copy/paste)

    #picoclaw
    kawkab-mono-font
    noto-fonts
    emacs
    emacs-all-the-icons-fonts
    kdePackages.okular

    (st.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or []) ++ [
        (pkgs.fetchpatch {
          url = "https://st.suckless.org/patches/fullscreen/st-fullscreen-0.8.5.diff";
          hash = "sha256-52lO6K9TGrrdPljXAFo+JB39XHeNF+0ru5QzDJ+9GX8="; 
        })
      ];

      postPatch = ''
        ${oldAttrs.postPatch or ""}

# XXX experimenting
        # 1. Change the font to IBM VGA 8x16, enable antialiasing/autohinting for crisp pixels
        #sed -i 's/font = ".*"/font = "PxPlus IBM VGA 8x16:pixelsize=32:antialias=false:autohint=false"/' config.def.h
        sed -i 's/font = ".*"/font = "AcPlus IBM VGA 8x16:pixelsize=32:antialias=true:autohint=false"/' config.def.h

        # 2. INJECT C CODE: Force X11 to launch the window in fullscreen mode
        sed -i '/XMapWindow(xw.dpy, xw.win);/i \    Atom netwmstate = XInternAtom(xw.dpy, "_NET_WM_STATE", False);\n    Atom netwmfullscreen = XInternAtom(xw.dpy, "_NET_WM_STATE_FULLSCREEN", False);\n    XChangeProperty(xw.dpy, xw.win, netwmstate, XA_ATOM, 32, PropModeReplace, (unsigned char *)&netwmfullscreen, 1);' x.c

	# 3. DISABLE BOLD / FAKE-SMEARING IN C CODE:
        # Tell st to request the regular font even when a program asks for bold
        sed -i 's/FC_WEIGHT_BOLD/FC_WEIGHT_REGULAR/g' x.c

	# Tell st not to artificially "smear" the regular font by overstriking it
        #sed -i 's/badweight = 1/badweight = 0/g' x.c

      '';
    }))
    #dash
    lldb
    mksh
    anki-bin
    obsidian
    pkgs-unstable.godot_4
    screenkey
    vlc
    scheherazade-new
    dbeaver-bin
    sqlite
    #graphviz
    #erd-go
    tbls
    #obs-studio
    #fd
    #xdotool
    libreoffice-fresh
    llvmPackages.libcxx

    clang
    clang-tools
    xmake
    cmake
    ninja
    gdb

    nodejs
    bashdb
    bashInteractive
    bash-language-server
    # The pure OpenVSX wrapper (bypasses broken NPM packages entirely)
    (writeShellScriptBin "bash-debug-adapter" ''
      CACHE_DIR="$HOME/.cache/emacs-bash-debug-v0.3.9"
      ADAPTER_JS="$CACHE_DIR/extension/out/bashDebug.js"
      
      if [ ! -f "$ADAPTER_JS" ]; then
        # Group everything and pipe to stderr (>&2) to protect Dape's JSON stdout stream
        {
          echo "📥 Bootstrapping official bash-debug from OpenVSX..."
          mkdir -p "$CACHE_DIR"
          ${pkgs.curl}/bin/curl -sL "https://open-vsx.org/api/rogalmic/bash-debug/0.3.9/file/rogalmic.bash-debug-0.3.9.vsix" -o "$CACHE_DIR/bash-debug.zip"
          ${pkgs.unzip}/bin/unzip -q "$CACHE_DIR/bash-debug.zip" -d "$CACHE_DIR"
          rm "$CACHE_DIR/bash-debug.zip"
        } >&2
      fi
      
      # NODE_NO_WARNINGS prevents node from outputting experimental warnings to stdout
      export NODE_NO_WARNINGS=1
      
      # THE WIRETAP: Pipe all internal crashes to a log file
      exec ${pkgs.nodejs}/bin/node "$ADAPTER_JS" "$@" 2> /tmp/dape-bash-error.log
    '')

    # 2. 🔥 bashunit (Using the standalone release artifact)
    (let
      bashunit-bin = pkgs.fetchurl {
        url = "https://github.com/TypedDevs/bashunit/releases/download/0.35.0/bashunit";
        hash = "sha256-b9NxedGQEB3+V9jIpw/W7FLFhAHdNJ1lEcUwAPkPuis="; 
        executable = true;
      };
    in pkgs.writeShellScriptBin "bashunit" "${bashunit-bin} \"$@\"")

    basedpyright

    #sqls
    xdg-utils
    xwininfo
    slack
    gedit
    nautilus
    dmenu
    i3lock
    brightnessctl
    pamixer
    networkmanagerapplet
    pnmixer
    adwaita-icon-theme
    hicolor-icon-theme
    pavucontrol
    alsa-utils
    xclip
    tree
    ripgrep
    xorg.xlsfonts
    xorg.xset
    xorg.fontmiscmisc
    xhost
    xeyes
    file
    xorg.libXpm
    #ghostty
    mlterm
    gnuplot
    sage
    fricas
    gnome-calculator
    #pkgs-unstable.ollama

    # THE PYTHON STACK
    (pkgs-unstable.python3.withPackages (ps: with ps; [
      fastapi
      uvicorn
      sympy
      #ollama
      #qwen-agent
      pypdf
      numpy
      pandas
    ]))
  ];
  # This forces st (and your user environment) to default to dash
  home.sessionVariables = {
    #SHELL = "${pkgs.dash}/bin/dash";
    SHELL = "${pkgs.mksh}/bin/mksh";
    ENV = "$HOME/.mkshrc";
  };

  # Generate the ~/.mkshrc file to enable vi bindings automatically
  home.file.".mkshrc".text = ''
    # Enable vi keybindings
    set -o vi
    alias cls="clear"
    alias ls="ls -F"
  '';

  # This configures volumeicon to show a slider and use your mixer
  xdg.configFile."volumeicon/volumeicon".text = ''
    [Alsa]
    card=default

    [StatusIcon]
    stepsize=5
    # This makes left-click show the slider
    lmb_slider=true
    # This makes middle-click mute
    mmb_mute=true
    # This opens your pro mixer on right-click
    rclick_command=pavucontrol
  '';

  programs.tmux = {
	  enable = true;
# Completely disable the sensible plugin and default NixOS bloat
	  sensibleOnTop = false;

# Ensure NO plugins are loaded
	  plugins = [];

# Inject minimal config directly
	  extraConfig = ''
# 1. Aggressively limit memory buffers
		  set -g history-limit 50        # The biggest RAM hog. Keep scrollback tiny.
		  set -g buffer-limit 1          # Limit copy-mode paste buffers
		  set -g word-separators ""      # Reduce parsing overhead

# 2. Kill the status bar (saves memory and CPU)
		  set -g status off              # Completely removes the status bar

# 3. Disable all interval polling
		  set -g status-interval 0       # Stop background ticking
		  set -g escape-time 0           # Remove keystroke delay handling
		  set -g focus-events off        # Disable cross-process focus tracking

# 4. Disable mouse processing
		  set -g mouse off               # Saves memory used for tracking coordinates

# 5. Disable visual fluff
		  set -g visual-activity off
		  set -g visual-bell off
		  set -g visual-silence off
		  '';
  };

  home.pointerCursor = {
   gtk.enable = true;
   # x11.enable is critical for i3 to see the change
   x11.enable = true;
   package = pkgs.vanilla-dmz;
   name = "Vanilla-DMZ";
   size = 48; # Standard is 16/24. Try 48 or 64 for a big cursor.
  };


  programs.google-chrome = {
    enable = true;
    commandLineArgs = [
      "--force-device-scale-factor=1.2" # 1.2 = 120% zoom.
    ];
  };

  programs.jujutsu = {
    enable = true;

    # This pulls the absolute bleeding-edge version directly from Jujutsu's repository
    package = inputs.jujutsu.packages.${pkgs.stdenv.hostPlatform.system}.default;

    settings = {
      ui.editor = "emacsclient";
      user = {
        name = "wirenpaper";
        email = "chumchumchira@gmail.com"; # Put your actual email here
      };
    };
  };

  # 2. Add the i3status configuration module
  programs.i3status = {
    enable = true;
    general = {
      colors = true;
      interval = 5;
    };
    # This defines the modules and their order
    modules = {
      "ipv6".enable = false;
      "wireless _first_".enable = false; # Set to true if you use Wi-Fi
      #"battery all".enable = false;      # if on laptop
      "battery all" = {
        enable = true;
        position = 9; # 9 puts it right between Volume (8) and Date (10)
        settings = {
          # %status shows charging/discharging, %percentage is the number
          # %remaining shows time left (e.g., 2h 30m)
          format = "%status %percentage %remaining";
          
          # Optional: Customize the status symbols
          status_chr = "⚡ CHR";  # Charging
          status_bat = "🔋 BAT";  # Discharging
          status_unk = "? UNK";   # Unknown
          status_full = "█ FULL"; # Full
          
          # Alert when battery is low (red color)
          low_threshold = 15;
          threshold_type = "percentage";
        };
      };
      "disk /".settings.format = "%avail";
      "load".settings.format = "%1min";
      "memory".settings.format = "%used | %available";
      
      # VOLUME PART
      "volume master" = {
        position = 8; 
        settings = {
          format = "♪: %volume";
          format_muted = "♪: muted (%volume)";
          device = "default";
          mixer = "Master";
          mixer_idx = 0;
        };
      };
      
      # THE DATE PART
      "tztime local" = {
        position = 10; # Usually at the end
        settings = {
          format = "{ %A } %d/%m/%Y %H:%M:%S"; 
        };
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = false;
    initContent = builtins.readFile ./extra_zsh_config.zsh;
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-gstreamer
      obs-vaapi # For hardware acceleration
    ];
  };

  #programs.neovim = {
  #  enable = true;

  #  extraLuaPackages = ps: [ ps.magick ]; # This is often required for image.nvim
  #  # This installs the Treesitter plugin AND the python/js parsers correctly compiled for NixOS
  #  plugins = with pkgs.vimPlugins; [
  #    (nvim-treesitter.withPlugins (p: [ 
  #      p.c 
  #      p.lua 
  #      p.python 
  #      p.javascript 
  #      p.vim 
  #      p.vimdoc 
  #      p.query 
  #      p.sql
  #      p.tree-sitter-norg
  #      p.tree-sitter-norg-meta
  #    ]))

  #    neorg
  #    plenary-nvim
  #    otter-nvim
  #    telescope-nvim

  #    lua-utils-nvim
  #    #pathlib-nvim
  #    nui-nvim
  #    nvim-nio
  #    neorg-telescope
  #    snacks-nvim
  #    image-nvim
  #  ];

  #  # key line
  #  package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;

  #  viAlias = true;
  #};

  home.file.".config/libreoffice/4/user/registrymodifications.xcu".source = ./registrymodifications.xcu;
}
