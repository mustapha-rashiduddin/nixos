{ pkgs, ... }:

let
  # Pinned to the exact `builtin-baseline` in CWR's vcpkg.json. Changing this
  # without changing the CWR manifest's baseline will break port resolution.
  vcpkgRev = "170bd3bfb152a1795b67b5c2190ab7d899fc9971";

  # Tag + sha512 taken verbatim from vcpkg's own scripts/vcpkg-tool-metadata.txt
  # at vcpkgRev, so bootstrap stays reproducible.
  vcpkgToolTag = "2026-05-27";
  vcpkgToolSha512 =
    "aaea34771d231f6cb4ba77d7646d7e2bab803fc2d42e6915c9ede77de224d9b71a1b4525b4faed39b33df9ab3bdf8f108fa6d61d55f6d198dca1ebb200c6d220";

  vcpkgRepoUrl = "https://github.com/microsoft/vcpkg.git";

  # vcpkg manifest mode resolves EVERY pinned port version (catch2@3.5.2,
  # cli11@2.4.0, mimalloc@2.2.4, spdlog@1.15.1, ...) by running
  # `git read-tree <tree>` against VCPKG_ROOT/.git, so the root needs the FULL
  # history, not just the baseline commit.
  #
  # That history cannot come from Nix: every nix git fetcher (fetchgit,
  # builtins.fetchTree, flake prefetch) is deliberately shallow or
  # blob-filtered, so a vcpkg root built from one always fails with "vcpkg was
  # cloned as a shallow repository" on the first `overrides` entry. Cloning in
  # a derivation does not help either — this system sets `sandbox = true` with
  # `sandbox-fallback = false`, and a per-derivation `sandbox = false` is not
  # honoured, so the build has no DNS.
  #
  # So the clone happens at runtime, once, in mkVcpkgRoot below, and is
  # verified against vcpkgRev. Everything that CAN be hermetic is: the vcpkg
  # tool itself is a real Nix derivation below.

  cwrSrc = pkgs.fetchgit {
    url = "https://github.com/BohemiaInteractive/CWR.git";
    rev = "ffc61838b7e756bec56aafafbf390396e639ac8f";
    hash = "sha256-OeMdzfKt7hgdvXCoTWDx4zIYlkclOrEDiCQ4ezPwcM4=";
  };

  # vcpkg-tool's own Find*.cmake modules FetchContent two dependencies at
  # configure time, which is impossible inside the Nix sandbox. Both modules
  # expose a URL cache variable, so pre-fetch the exact tarballs they want
  # (hashes are vcpkg's own, not ours) and point them at the store instead.
  cmrcSrc = pkgs.fetchurl {
    url = "https://github.com/vector-of-bool/cmrc/archive/refs/tags/2.0.1.tar.gz";
    sha512 = "cb69ff4545065a1a89e3a966e931a58c3f07d468d88ecec8f00da9e6ce3768a41735a46fc71af56e0753926371d3ca5e7a3f2221211b4b1cf634df860c2c997f";
  };

  # Headers only: VCPKG_LIBCURL_DLSYM defaults ON off-Windows, so vcpkg
  # dlopen()s the real libcurl at runtime and never links it. These must match
  # the SHA512/URL pair in FindLibCURL.cmake for the branch cmake selects.
  libcurlHeadersSrc = pkgs.fetchurl {
    url = "https://curl.se/download/archeology/curl-7.29.0.tar.gz";
    sha512 = "08bafd09fa6d14362a426932fed8528c13133895477d8134c829e085637956d66d6be5a791057c1c04da04af6baa6496a6d59e00abf9ca6be5d29e798718b9bc";
  };

  # vcpkg ships a prebuilt glibc binary, but NixOS has no
  # /lib64/ld-linux-x86-64.so.2, so it dies with "Could not start dynamically
  # linked executable". Build the tool from source against Nix's glibc instead.
  vcpkgTool = pkgs.stdenv.mkDerivation {
    pname = "vcpkg-tool";
    version = vcpkgToolTag;

    src = pkgs.fetchurl {
      url =
        "https://github.com/microsoft/vcpkg-tool/archive/${vcpkgToolTag}.zip";
      sha512 = vcpkgToolSha512;
    };

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
      pkgs.patchelf
      pkgs.unzip
      pkgs.fmt
      # FindCMakeRC.cmake shells out to git to resolve its pinned tag.
      pkgs.git
    ];
    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DVCPKG_DEVELOPMENT_WARNINGS=OFF"
      # Findfmt.cmake otherwise FetchContents fmt over the network. nixpkgs ships
      # fmt 12.1.0, which is exactly the version it would download anyway.
      "-DVCPKG_DEPENDENCY_EXTERNAL_FMT=ON"
      "-DVCPKG_CMAKERC_URL=${cmrcSrc}"
      "-DVCPKG_LIBCURL_URL=${libcurlHeadersSrc}"
    ];
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      # The zip unpacks into a vcpkg-tool-<tag>/ subdir, so the cmake build
      # tree is not at a fixed depth. Locate the linked binary rather than
      # guessing a relative path.
      tool="$(find . -type f -name vcpkg -perm -u+x -not -path '*/CMakeFiles/*' | head -n1)"
      if [ -z "$tool" ]; then
        echo "cwr.nix: could not find the built vcpkg binary" >&2
        exit 1
      fi
      install -Dm755 "$tool" $out/vcpkg

      # vcpkg-tool dlopen()s libcurl at runtime rather than linking it, so the
      # compiler wrapper never records an rpath for it. Point RUNPATH at Nix's
      # curl or every vcpkg invocation dies with "unable to find libcurl.so.4".
      # --set-rpath replaces rather than appends, so keep whatever the stdenv
      # wrapper already added (libfmt via the external-FMT switch, libstdc++).
      existing="$(patchelf --print-rpath "$out/vcpkg" 2>/dev/null || true)"
      [ -n "$existing" ] || existing="$out/lib"
      # curl has outputs [ bin dev out man devdoc debug ], so pkgs.curl would
      # give us the bin output, which ships no libcurl.so.4.
      patchelf --set-rpath \
        "$existing:${pkgs.fmt}/lib:${pkgs.curl.out}/lib:${pkgs.zlib}/lib" \
        $out/vcpkg

      runHook postInstall
    '';
  };

  # Everything the triplet's `clang`/`clang++` and vcpkg's port builds need.
  # `clang` must resolve first: cmake/vcpkg-triplets/x64-linux-clang.cmake
  # hardcodes bare `clang`, and the CWR toolchain file does the same.
  toolchain = with pkgs; [
    clang
    clang-tools
    lld
    cmake
    ninja
    ccache
    pkg-config
    patchelf
    git
    zip
    unzip
    curl
    bzip2
    xz
    python3
  ];

  # vcpkg needs a WRITABLE VCPKG_ROOT: it creates downloads/, buildtrees/,
  # packages/ and installed/ inside it, and runs `git read-tree` against .git
  # to materialise the pinned port versions. The store is read-only, so
  # materialise a private copy on first use and reuse it on every later run.
  mkVcpkgRoot = pkgs.writeShellScript "cwr-vcpkg-root" ''
    set -euo pipefail
    dest="''${XDG_CACHE_HOME:-$HOME/.cache}/cwr/vcpkg"
    stamp="$dest/.cwr-stamp"

    # Re-materialise automatically if either pin ever moves.
    want="${vcpkgRev} ${vcpkgToolTag}"
    if [ -e "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$want" ]; then
      echo "$dest"
      exit 0
    fi

    echo "cwr: cloning vcpkg at ${vcpkgRev} into $dest (one time, ~250 MB)" >&2

    if [ -e "$dest" ]; then
      chmod -R u+w "$dest" 2>/dev/null || true
      rm -rf "$dest"
    fi

    # Full clone: manifest versioning needs the tree objects behind every
    # pinned port version, which a shallow checkout does not contain.
    ${pkgs.git}/bin/git clone --quiet ${vcpkgRepoUrl} "$dest"
    ${pkgs.git}/bin/git -C "$dest" checkout --quiet ${vcpkgRev}

    actual="$(${pkgs.git}/bin/git -C "$dest" rev-parse HEAD)"
    if [ "$actual" != "${vcpkgRev}" ]; then
      echo "cwr.nix: vcpkg rev mismatch: wanted ${vcpkgRev}, got $actual" >&2
      exit 1
    fi

    # The Nix-built tool, not the upstream prebuilt one: the prebuilt binary
    # is generic-Linux dynamically linked and cannot exec on NixOS at all.
    install -Dm755 ${vcpkgTool}/vcpkg "$dest/vcpkg"

    # vcpkg identifies its root by this marker and reads the expected tool
    # version from scripts/vcpkg-tool-metadata.txt, so both must be present.
    touch "$dest/.vcpkg-root" "$dest/vcpkg.disable-metrics"
    printf '%s\n' "$want" > "$stamp"

    echo "$dest"
  '';

  # Shared preamble: puts the toolchain on PATH and exports the two variables
  # without which vcpkg reaches for prebuilt generic-Linux binaries and dies.
  envSetup = ''
    export PATH="${pkgs.lib.makeBinPath toolchain}:$PATH"
    export VCPKG_ROOT="$(${mkVcpkgRoot})"

    # Without this, vcpkg downloads its own cmake/ninja and cannot exec them.
    export VCPKG_FORCE_SYSTEM_BINARIES=1

    # Keep telemetry off and binary caching off. A remote binary cache would
    # hand us glibc-linked prebuilts that are wrong for NixOS anyway.
    export VCPKG_DISABLE_METRICS=1
    unset X_VCPKG_ASSET_SOURCES || true
  '';

  # 7.4 GiB RAM: ninja's default of nproc+2 will OOM on a link this size.
  # lld is on PATH and picked up by the compiler, which is the bigger win.
  cwrBuild = pkgs.writeShellScriptBin "cwr-build" ''
    set -euo pipefail
    ${envSetup}

    src="''${CWR_DIR:-$HOME/dev/CWR}"
    preset="''${CWR_PRESET:-linux-x64-clang-rwdi}"
    jobs="''${CWR_JOBS:-4}"
    target="''${1:-all}"

    [ -f "$src/CMakeLists.txt" ] || {
      echo "no CWR checkout at $src (override with CWR_DIR)" >&2
      exit 1
    }

    cd "$src"
    echo "==> configure: $preset"
    cmake --preset "$preset"
    echo "==> build: $target (-j$jobs)"
    ninja -C "build/$preset" -j "$jobs" "$target"
  '';

  # Interactive shell with the same environment, for poking at headers or
  # running the engine's tools against an already-built tree.
  cwrShell = pkgs.writeShellScriptBin "cwr-shell" ''
    ${envSetup}
    export CWR_DIR="''${CWR_DIR:-$HOME/dev/CWR}"
    cd "$CWR_DIR"
    exec ${pkgs.bash}/bin/bash "$@"
  '';

  # Pinned upstream tree, for when you want a clean source instead of your
  # working clone. Note: the engine itself is NOT built here — it needs vcpkg
  # and takes far longer than is sane to wrap in a nix derivation.
  source = pkgs.writeShellScriptBin "cwr-source" ''
    exec ${pkgs.git}/bin/git clone \
      https://github.com/BohemiaInteractive/CWR.git \
      "''${CWR_DIR:-$HOME/dev/CWR}"
  '';

in
rec {
  inherit cwrSrc vcpkgTool cwrBuild cwrShell source;
}
