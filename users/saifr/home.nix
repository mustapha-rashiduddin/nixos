{ config, pkgs, inputs, ... }:

let 
  erd-go = import ./erd-go.nix { inherit pkgs; };
  qwen-agent = import ./qwen-agent.nix { inherit pkgs; };

  lua-utils-nvim = import ./lua-utils-nvim.nix { inherit pkgs; };
  pathlib-nvim = import ./pathlib-nvim.nix { inherit pkgs; };
in
{
  # THIS MUST BE HERE AT THE TOP LEVEL
  home.stateVersion = "25.11";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.shellAliases = {
    theme = "~/.config/config-manager/theme.sh";

    dbdraw = "RULES=\"s|>id |>[PK] id |g; s|>([a-z0-9_]+_id) |>[FK] \\1 |g;\"; for c in \$(sqlite3 project.db \"SELECT ii.name FROM sqlite_master m, pragma_index_list(m.name) il, pragma_index_info(il.name) ii WHERE il.\\\"unique\\\" = 1 AND il.origin != 'pk' AND m.type = 'table'\" | sort -u); do RULES=\"\${RULES} s|>\${c} |>(U) \${c} |g;\"; done; for c in \$(sqlite3 project.db \"SELECT p.name FROM sqlite_master m, pragma_table_info(m.name) p WHERE p.\\\"notnull\\\" = 1 AND m.type = 'table' AND p.name != 'id' AND p.name NOT LIKE '%_id'\" | sort -u); do RULES=\"\${RULES} s|>\\(U\\) \${c} |>(U)* \${c} |g; s|>\${c} |>* \${c} |g;\"; done; tbls out \"sqlite:///$(pwd)/project.db\" --format dot | sed -E \"\${RULES} s|taillabel=<<table.*table>>||g\" | dot -Tpng -Gsplines=polyline -Grankdir=LR -Gnodesep=1 -Granksep=1 -o schema.png && timg --upscale schema.png";

    dbdraw-dark = "RULES=\"s|>id |>[PK] id |g; s|>([a-z0-9_]+_id) |>[FK] \\1 |g;\"; for c in \$(sqlite3 project.db \"SELECT ii.name FROM sqlite_master m, pragma_index_list(m.name) il, pragma_index_info(il.name) ii WHERE il.\\\"unique\\\" = 1 AND il.origin != 'pk' AND m.type = 'table'\" | sort -u); do RULES=\"\${RULES} s|>\${c} |>(U) \${c} |g;\"; done; for c in \$(sqlite3 project.db \"SELECT p.name FROM sqlite_master m, pragma_table_info(m.name) p WHERE p.\\\"notnull\\\" = 1 AND m.type = 'table' AND p.name != 'id' AND p.name NOT LIKE '%_id'\" | sort -u); do RULES=\"\${RULES} s|>\\(U\\) \${c} |>(U)* \${c} |g; s|>\${c} |>* \${c} |g;\"; done; tbls out \"sqlite:///$(pwd)/project.db\" --format dot | sed -E \"s|bgcolor=\\\"[^\\\"]*\\\"||g; s|<table|<table bgcolor=\\\"#252525\\\"|g; \${RULES} s|taillabel=<<table.*table>>||g\" | dot -Tpng -Gbgcolor='#181818' -Nfontcolor='#ffaf00' -Ncolor='#181818' -Ecolor='#666666' -Gsplines=polyline -Grankdir=LR -Gnodesep=1 -Granksep=1 -o schema.png && timg --upscale schema.png";
  };

  programs.gemini-cli = {
    enable = true;
  };

  home.packages = with pkgs; [
    vim

    sqlite
    graphviz
    erd-go 
    tbls
    tmux

    xdotool
    libreoffice-fresh
    gcc
    nodejs

    basedpyright
    sqls

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
    ghostty
    kitty

    gnuplot

    sage
    fricas

    gnome-calculator

    texliveFull
    rlwrap
    timg
    imagemagick
    ghostscript
    poppler-utils
    inotify-tools

    # THE PYTHON STACK
    (python3.withPackages (ps: with ps; [
      fastapi
      uvicorn
      sympy
      ollama
      qwen-agent
      pypdf
    ]))
  ];

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
          status_full = "☻ FULL"; # Full
          
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

  programs.neovim = {
    enable = true;

    extraLuaPackages = ps: [ ps.magick ]; # This is often required for image.nvim
    # This installs the Treesitter plugin AND the python/js parsers correctly compiled for NixOS
    plugins = with pkgs.vimPlugins; [
      (nvim-treesitter.withPlugins (p: [ 
        p.c 
        p.lua 
        p.python 
        p.javascript 
        p.vim 
        p.vimdoc 
        p.query 
	p.sql
        p.tree-sitter-norg
        p.tree-sitter-norg-meta
      ]))

      neorg
      plenary-nvim
      otter-nvim
      telescope-nvim

      lua-utils-nvim
      pathlib-nvim
      nui-nvim
      nvim-nio
      neorg-telescope
      snacks-nvim
      image-nvim
    ];

    # key line
    package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;

    viAlias = true;
    #vimAlias = true;
  };

  home.file.".config/i3/config".text = builtins.readFile ./i3-config;
  home.file.".config/libreoffice/4/user/registrymodifications.xcu".source = ./registrymodifications.xcu;
  #home.file.".tmux.conf".source = ./tmux.conf;
}
