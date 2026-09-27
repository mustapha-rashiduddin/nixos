{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.mySetups.jev;

  # The secrets stay optional so the config still builds before the keys have been
  # added to secrets.yaml. Encrypted entries keep their top-level YAML key, so
  # their presence is readable without decrypting anything.
  inSops = name: lib.any (line: lib.hasPrefix "${name}:" (lib.removeSuffix "\r" line))
    (lib.splitString "\n" (builtins.readFile ../secrets.yaml));
in
{
  options.mySetups.jev.enable = lib.mkEnableOption "Jev (TypeSafe System One) API key setup";

  config = lib.mkIf cfg.enable {
    home-manager.users.saifr = { config, ... }: {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops = {
        defaultSopsFile = ../secrets.yaml;
        defaultSopsFormat = "yaml";
        age.keyFile = "/home/saifr/.config/sops/age/keys.txt";
      } // lib.optionalAttrs (inSops "typesafe_api_key") {
        # TypeSafe's own console; signups paused 2026-09-22.
        secrets.typesafe_api_key = {
          path = "/home/saifr/.config/typesafe/api_key";
          mode = "0600";
        };
      } // lib.optionalAttrs (inSops "openrouter_api_key") {
        # OpenRouter proxies the same Jev models and signs you up without a waitlist.
        secrets.openrouter_api_key = {
          path = "/home/saifr/.config/openrouter/api_key";
          mode = "0600";
        };
      };
    };
  };
}
