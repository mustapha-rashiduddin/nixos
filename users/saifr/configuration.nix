{ config, pkgs, inputs, ... }:

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
  
  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

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
    displayManager.lightdm.enable = true;
    windowManager.i3.enable = true;
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
    ];
    
    # This is the "Magic Switch" that makes NixOS link these to X11
    fontDir.enable = true;

    # This allows the "Bitmap" fonts that modern systems usually ignore
    fontconfig.allowBitmaps = true;
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
    extraSpecialArgs = { inherit inputs; };
    
    # Point to the home.nix in this folder
    users.saifr = import ./home.nix;
  };

  system.stateVersion = "25.11"; 
}
