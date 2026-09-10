{ pkgs, ... }:

let
  pyPkgs = pkgs.python3.pkgs;

  # lib50 caps termcolor at <2 but nixpkgs 25.11 only ships 3.x; vendor the
  # 1.1.0 that check50's own venv install resolves to.
  termcolor_1_1 = pyPkgs.buildPythonPackage {
    pname = "termcolor";
    version = "1.1.0";
    src = pyPkgs.fetchPypi {
      pname = "termcolor";
      version = "1.1.0";
      sha256 = "0fv1vq14rpqwgazxg4981904lfyp84mnammw7y046491cv76jv8x";
    };
    pyproject = true;
    build-system = [ pyPkgs.setuptools ];
  };

  lib50 = pyPkgs.buildPythonApplication {
    pname = "lib50";
    version = "3.2.3";
    src = pyPkgs.fetchPypi {
      pname = "lib50";
      version = "3.2.3";
      sha256 = "0lij9zwgjxrhlga37kk7mkfbixw3f2sykck0d2sfmxmspl6ib97j";
    };
    pyproject = true;
    build-system = [ pyPkgs.setuptools ];
    propagatedBuildInputs = with pyPkgs; [
      packaging
      pexpect
      pyyaml
      requests
      setuptools
      termcolor_1_1
      jellyfish
      cryptography
    ];
    meta.mainProgram = "lib50";
  };
in
pyPkgs.buildPythonApplication {
  pname = "check50";
  version = "3.4.0";
  src = pyPkgs.fetchPypi {
    pname = "check50";
    version = "3.4.0";
    sha256 = "16p89c4pyxcs4238i6bi5z3f5328r9aizba3zp7b1kf1fk7a65wa";
  };
  pyproject = true;
  build-system = [ pyPkgs.setuptools ];
  propagatedBuildInputs = with pyPkgs; [
    attrs
    beautifulsoup4
    lib50
    packaging
    pexpect
    pyyaml
    requests
    setuptools
    termcolor_1_1
    jinja2
  ];
  meta.mainProgram = "check50";
}