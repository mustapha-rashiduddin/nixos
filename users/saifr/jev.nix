{ pkgs, pkgs-unstable, ... }:

let
  pypkgs = pkgs-unstable.python3Packages;

  typesafe-sdk = pypkgs.buildPythonPackage {
    pname = "typesafe-sdk";
    version = "0.7.1";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/75/72/7e57648d27e45260b04762dd2393a81604b516a282fc5efe94cdf90ab971/typesafe_sdk-0.7.1-py3-none-any.whl";
      sha256 = "9d04eee13b5f64bbbe6f8e96cf40e3f39ca4efc934a1f4f39490cb9a43e9d2ad";
    };
    propagatedBuildInputs = with pypkgs; [
      httpx2
      pydantic
      tenacity
      typing-extensions
    ];
  };

  pythonEnv = pkgs-unstable.python3.withPackages (ps: [ typesafe-sdk ]);
in
rec {
  inherit typesafe-sdk pythonEnv;

  cli = pkgs.writeShellScriptBin "jev" ''
    exec ${pythonEnv}/bin/python ${./jev_cli.py} "$@"
  '';
}
