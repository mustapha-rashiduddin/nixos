{ config, pkgs, pkgs-unstable, inputs, cosmicTerminalFontName, ... }:

let 
  #erd-go = import ./erd-go.nix { inherit pkgs; };
  #qwen-agent = import ./qwen-agent.nix { inherit pkgs; };
  #lua-utils-nvim = import ./lua-utils-nvim.nix { inherit pkgs; };
  #pathlib-nvim = import ./pathlib-nvim.nix { inherit pkgs; };
  #picoclaw = import ./picoclaw.nix { inherit pkgs pkgs-unstable; };
  #nanobot = import ./nanobot.nix { inherit pkgs; };   # <-- add this

  fresh-ide = import ./fresh-ide.nix { inherit pkgs; }; # <--- ADD THIS HERE
  webots = import ./webots.nix { inherit pkgs; }; # <--- ADD THIS

  litecli = import ./litecli.nix { inherit pkgs; };
  
  nastaliqZip = pkgs.fetchurl {
    url = "https://github.com/notofonts/nastaliq/releases/download/NotoNastaliqUrdu-v4.000/NotoNastaliqUrdu-v4.000.zip";
    sha256 = "sha256-ByWnqd/UUJYbGCJ0RcyaXSFiTWix+I+lLkxqD+dXZyg=";
  };
  nastaliqFont = pkgs.runCommand "noto-nastaliq-urdu" {} ''
    mkdir -p $out/share/fonts/truetype
    ${pkgs.unzip}/bin/unzip ${nastaliqZip} -d $out/share/fonts/truetype
  '';
in
{
  # THIS MUST BE HERE AT THE TOP LEVEL
  home.stateVersion = "25.11";

  #home.sessionVariables = {
  #  EDITOR = "nvim";
  #};

  # No theme aliases here: light/dark (and clight/cdark) are mksh-only,
  # defined in the ~/.mkshrc block below.

  #programs.gemini-cli = {
  #  enable = true;
  #};

  home.packages = with pkgs; [
    wl-clipboard
    fresh-ide
    wgnord
    openvpn
    wireguard-tools
    brave
    vscode
    discord
    polkit_gnome
    # xdg-desktop-portal
    # xdg-desktop-portal-gtk
    dunst
    wesnoth

      ((vim-full.override {
    features = "huge";
    guiSupport = true;
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
    helix
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

	# Remove the Alt+Return fullscreen binding from the fullscreen patch.
	# It collides with rainfrog's Alt+Enter query-execute keybinding.
	# (F11 fullscreen binding is kept; i3 $mod+g also toggles fullscreen.)
        sed -i '/XK_Return.*fullscreen/d' config.def.h

# XXX experimenting
        # 1. Font: CMU Typewriter Text semi-bold, same family/weight as ghostty
        #    (font-style = SemiBold) and emacs (my/font-typewriter). There is no
        #    true SemiBold face, so weight=semibold resolves to the Bold face.
        #    size 20pt == pixelsize 27 at ~97dpi, matching the frame default.
        #sed -i 's/font = ".*"/font = "PxPlus IBM VGA 8x16:pixelsize=32:antialias=false:autohint=false"/' config.def.h
        sed -i 's/font = ".*"/font = "CMU Typewriter Text:pixelsize=27:weight=semibold:antialias=true:autohint=false"/' config.def.h

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
    (rust-bin.stable.latest.default.override {
      extensions = [ "clippy" "rustfmt" "rust-src" ];
    })
    unzip
    litecli
    anki-bin
    imagemagick
    obsidian
    pkgs-unstable.godot_4
    pkgs-unstable.opencode 
    screenkey
    vlc
    scheherazade-new
    nastaliqFont
    dbeaver-bin
    sqlite
    inputs.syntaqlite.packages.${pkgs.stdenv.hostPlatform.system}.default
    graphviz
    #erd-go
    tbls
    rainfrog
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
    gh
    cosmic-term
    xdg-utils
    xwininfo
    slack
    fish
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
    ghostty
    mlterm
    gnuplot
    sage
    fricas
    gnome-calculator
    jq
    postman
    #pkgs-unstable.ollama
    webots

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
    BROWSER = "google-chrome-stable"; 
  };

  # Cargo-installed tools (`erd`) on PATH for the HM-managed shells (fish, zsh).
  # HM sources this session-vars file unconditionally in config.fish / .zshrc,
  # so it reaches non-login interactive shells that never run /etc/profile.
  # (Login shells get the same path from configuration.nix
  #  environment.sessionVariables.PATH; non-login mksh gets it from .mkshrc.)
  home.sessionPath = [ "$HOME/.cargo/bin" ];

  # Generate the ~/.mkshrc file to enable vi bindings automatically.
  # mksh is interactive (non-login) via ENV=$HOME/.mkshrc, so it does NOT
  # source /etc/profile. The system-level environment.sessionVariables.PATH
  # (configuration.nix) only reaches login shells; this line covers routines
  # started interactively (terminal + tmux), so `erd` resolves everywhere.
  home.file.".mkshrc".text = ''
    # Enable vi keybindings
    set -o vi
    export PATH="$HOME/.cargo/bin:$PATH"
    alias cls="clear"
    alias ls="ls -F"
    # esync - Emacs speed-dial workspace jump
    . "$HOME/.config/esync/scripts/esync.sh"
    # plant - plant current dir as the global speed-dial workspace
    . "$HOME/.config/plant/scripts/plant.sh"
    # load - materialize and protect an i3 project loadout (default: ./loadout)
    . "$HOME/.config/load/scripts/load.sh"
    # theme - switch st/neovim between light and dark (mksh only)
    alias light="$HOME/.config/config-manager/theme.sh light"
    alias dark="$HOME/.config/config-manager/theme.sh dark"
    # ghostty/cosmic theme (mksh only)
    alias clight="$HOME/.config/config-manager/theme.sh clight"
    alias cdark="$HOME/.config/config-manager/theme.sh cdark"
    # theme - repaint st colors on every prompt (output-direction OSC, safe
    # even right after an app like nvim/erdcat exits and owns the screen)
    [ "$(ps -o comm= -p "$PPID" 2>/dev/null)" = "st" ] && IS_ST=1 || IS_ST=0
    st_theme_osc() {
        [ "$IS_ST" = 1 ] || return
        fg=$(cat "$HOME/.config/config-manager/current-st-fg" 2>/dev/null) || return
        bg=$(cat "$HOME/.config/config-manager/current-st-bg" 2>/dev/null) || return
        [ -n "$fg" ] && [ -n "$bg" ] || return
        command printf '\033]11;#%s\007\033]10;#%s\007\033]12;#%s\007' "$bg" "$fg" "$fg"
    }
    PS1='$(st_theme_osc)$ '
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

  programs.fish = {
    enable = true;

    # PATH for cargo-installed tools (`erd`) comes from the system-level
    # environment.sessionVariables.PATH in configuration.nix, so every shell
    # inherits it at login. fish needs no explicit PATH line here.
    interactiveShellInit = ''
      set -g fish_greeting ""
      fish_vi_key_bindings
      source $HOME/.config/esync/scripts/esync.fish
      source $HOME/.config/plant/scripts/plant.fish
      source $HOME/.config/load/scripts/load.fish
    '';
  };

  xdg.configFile."cosmic/com.system76.CosmicTerm/v1/font_name".text =
    builtins.toJSON cosmicTerminalFontName + "\n";

  xdg.configFile."cosmic/com.system76.CosmicTerm/v1/font_weight".text = ''
    600
  '';

  xdg.configFile."cosmic/com.system76.CosmicTerm/v1/dim_font_weight".text = ''
    600
  '';

  xdg.configFile."cosmic/com.system76.CosmicTerm/v1/bold_font_weight".text = ''
    700
  '';

  xdg.configFile."cosmic/com.system76.CosmicTerm/v1/show_headerbar".text = ''
    false
  '';

  xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/corner_radii".text = ''
    (
      radius_0: (0.0, 0.0, 0.0, 0.0),
      radius_xs: (0.0, 0.0, 0.0, 0.0),
      radius_s: (0.0, 0.0, 0.0, 0.0),
      radius_m: (0.0, 0.0, 0.0, 0.0),
      radius_l: (0.0, 0.0, 0.0, 0.0),
      radius_xl: (0.0, 0.0, 0.0, 0.0),
    )
  '';

  xdg.configFile."cosmic/com.system76.CosmicTheme.Light/v1/corner_radii".text = ''
    (
      radius_0: (0.0, 0.0, 0.0, 0.0),
      radius_xs: (0.0, 0.0, 0.0, 0.0),
      radius_s: (0.0, 0.0, 0.0, 0.0),
      radius_m: (0.0, 0.0, 0.0, 0.0),
      radius_l: (0.0, 0.0, 0.0, 0.0),
      radius_xl: (0.0, 0.0, 0.0, 0.0),
    )
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

  #gtk = {
  #  enable = true;
  #  font = {
  #    name = "CMU Typewriter Text"; # Or any font you have installed
  #    size = 18;            # Increase this for larger Emacs menus
  #  };
  #};
  xresources.properties = {
    "Emacs.pane.menubar.font" = "xft:CMU Typewriter Text:size=14";
    "Emacs.menu*.font"        = "xft:CMU Typewriter Text:size=14";
  };


  programs.google-chrome = {
    enable = true;
    commandLineArgs = [
      "--force-device-scale-factor=1.2" # 1.2 = 120% zoom.
    ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
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

  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = 0.0;     
    longitude = 0.0;
    temperature = {
      day = 2500;       
      night = 2500;      
    };
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-gstreamer
      obs-vaapi # For hardware acceleration
    ];
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
  };

  home.file.".config/libreoffice/4/user/registrymodifications.xcu".source = ./registrymodifications.xcu;
}
