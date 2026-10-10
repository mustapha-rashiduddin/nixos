{ pkgs, pkgs-unstable, ... }:

let
  # Upstream requires onnxruntime>=1.23.2 and llguidance>=1.8. nixpkgs 25.11
  # ships 1.22.2 and 1.4.0, so the pinned channel cannot satisfy the floors
  # and pythonRelaxDeps would be papering over a genuinely too-old runtime
  # (llguidance's constrained-decoding API is what changed). Build against
  # unstable instead, where both are current.
  #
  # python313, not unstable's default python3: unstable ships 3.14 and the
  # package declares requires-python = ">=3.10, <3.14". 3.13 also matches the
  # Python the rest of the desktop tooling is on.
  pypkgs = pkgs-unstable.python313Packages;

  # The weights are published in the gated repo neuphonic/neudecide, which
  # answers 401 until an account accepts the terms. The public demo Space
  # carries byte-identical q4 graphs, so vendoring from there gives the same
  # model with no account, no token and no network at runtime.
  #
  # The Space's archive endpoint only emits LFS pointers, so the graphs are
  # fetched one file at a time. spaceRev pins the Space commit, so these URLs
  # are immutable.
  spaceRev = "e1b1388cdf210f523d9bb22b6a0e3ba6b546ea0f";
  spaceUrl = path:
    "https://huggingface.co/spaces/neuphonic/neudecide/resolve/${spaceRev}/model/${path}";

  graphFiles = {
    "audio_encoder_q4.onnx" = "sha256-KsXEjhdmOCc27Y3U1GhWjuWDU2VQ+3QawYchn4zY2ps=";
    "tool_encoder_q4.onnx" = "sha256-SlB17iho2Q6kvjI06uBAAb5ohslzDodGQh+hfoQxPYU=";
    "decoder_step_q4.onnx" = "sha256-7mi7tLvKVSuQm0HLH9v98PnzyFJWHhgDYETuL/Rh5Q0=";
    "config.json" = "sha256-P7OUXSNFMbOxeo6VkpazdIdtD2B4jafGfV4y+2bK7YQ=";
    "tokenizer.json" = "sha256-KzHyt5UGzKNrPGPw6FSehAHdjXaBdcV6oeZ0Mtad7g0=";
  };

graphSources =
    pkgs.lib.mapAttrs (_: hash: pkgs.fetchurl { url = spaceUrl _; inherit hash; }) graphFiles;

  # Symlinks, not copies: every graph is already an immutable store path, so
  # this costs 43MB of references instead of 43MB of data.
  #
  # Linked under the attribute name rather than the store basename, which
  # carries a content hash ("<hash>-config.json"); the loader looks the files
  # up by the plain names config.json names in its graphs table.
  model = pkgs.runCommand "neudecide-model-q4"
    { version = "0.1.0"; }
    (builtins.concatStringsSep "\n" (pkgs.lib.mapAttrsToList
      (name: src: "mkdir -p $out\nln -s ${toString src} $out/${name}")
      graphSources));

  neudecideRev = "548134f512f11dfe249acde3110c05c3a4774871";

  # Upstream's own example assets, so `neudecide --demo` has something to say
  # and there is a known-good clip to compare against.
  demoWav = pkgs.fetchurl {
    url = "https://github.com/neuphonic/neudecide/raw/${neudecideRev}/examples/command.wav";
    hash = "sha256-1bUs+JnD+KXjpe+hFGkWJQj80E/R5F/4Eir8vW7RHZM=";
  };

  demoTools = pkgs.fetchurl {
    url = "https://github.com/neuphonic/neudecide/raw/${neudecideRev}/examples/tools.json";
    hash = "sha256-ImfE0JoATUNOg0DsRS/eklAM71g5q2P3rERk+MEacIQ=";
  };

  # Upstream ships no entry points (a library plus examples/), so the CLI is
  # a separate wrapper rather than a console script. It points at the
  # vendored model directory, which is what keeps the HF gate out of the
  # picture: from_pretrained() is never reached, so nothing asks for a token.
  pythonEnv = pypkgs.python.withPackages (ps: [ neudecide_custom ]);

  cli = pkgs.writeShellScriptBin "neudecide" ''
    export PATH=${pkgs.lib.makeBinPath [ pkgs.alsa-utils ]}:$PATH
    exec ${pythonEnv}/bin/python ${./neudecide_cli.py} \
      --model ${model} \
      --demo-audio ${demoWav} \
      --default-tools ${demoTools} \
      "$@"
  '';

  neudecide_custom = pypkgs.buildPythonPackage {
    pname = "neudecide_custom";
    version = "0.1.0";
    format = "pyproject";

    src = pkgs.fetchFromGitHub {
      owner = "neuphonic";
      repo = "neudecide";
      rev = neudecideRev;
      hash = "sha256-XzrADMODaJPRfWLqemQgOvXnBC/UzWpaIAWkw29k8vU=";
    };

    nativeBuildInputs = [ pypkgs.setuptools ];

    propagatedBuildInputs = with pypkgs; [
      huggingface-hub
      llguidance
      numpy
      onnxruntime
      protobuf
      sentencepiece
      soxr
    ];

    pythonImportsCheck = [ "neudecide" ];

    # The test suite's slow marker downloads the gated repo, which needs a
    # token the build has no business having.
    doCheck = false;

    meta = with pkgs.lib; {
      description = "NeuDecide - a tiny audio-first voice-action model (q4 ONNX, CPU)";
      homepage = "https://github.com/neuphonic/neudecide";
      license = licenses.asl20;
      platforms = platforms.unix;
    };
  };
in
{
  inherit neudecide_custom cli model pythonEnv;
}