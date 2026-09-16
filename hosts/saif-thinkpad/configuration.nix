{ config, pkgs, ... }:

{
  networking.hostName = "saif-thinkpad"; 
  services.printing.enable = true;
  services.udev.extraRules = ''
    KERNEL=="leds/tpacpi::power", MODE="0660", GROUP="wheel"
  '';

  imports = [
    ./hardware-configuration.nix
    ../../users/saifr/configuration.nix
    ../../modules
  ];

  mySetups.ollama.enable = true;
  # mySetups.thinkpad-sops.enable = true;
  mySetups.vertex.enable = true;
}
