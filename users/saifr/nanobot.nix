{ pkgs }:

with pkgs.python3Packages;

let
  # Since oauth-cli-kit is not in Nixpkgs, we quickly package it ourselves inline
  oauth-cli-kit = buildPythonPackage rec {
    pname = "oauth_cli_kit";
    version = "0.1.3";
    format = "pyproject";

    src = fetchPypi {
      pname = "oauth_cli_kit";
      inherit version;
      hash = "sha256-ZhKz3qGpfE3kp9O4KHZ9QvCnjq6Tvla5DFXTq2aOv7g=";
    };

    nativeBuildInputs =[ setuptools hatchling hatch-vcs ];
    propagatedBuildInputs = [ httpx platformdirs ];

    doCheck = false;
  };

in
buildPythonApplication rec {
  pname = "nanobot-ai";
  version = "0.1.4.post3";

  src = fetchPypi {
    pname = "nanobot_ai";
    inherit version;
    hash = "sha256-kafCJXfBjogjRfWPQkBLGcnH/RgEuAuEv4XRuA/cP1g=";
  };

  format = "pyproject";

  nativeBuildInputs =[
    hatchling
    pythonRelaxDepsHook
  ];

  propagatedBuildInputs =[
    openai
    anthropic
    typer
    rich
    pydantic
    pydantic-settings
    httpx
    croniter
    loguru
    prompt-toolkit
    msgpack
    websockets
    websocket-client
    python-socks
    socksio
    json-repair
    litellm
    # Inject our newly packaged oauth library here!
    oauth-cli-kit
  ];

  # Relaxes strict version limits so older versions in Nixpkgs work!
  pythonRelaxDeps =[
    "python-socks"
    "pydantic"
    "pydantic-settings"
    "websocket-client"
    "typer"
    "websockets"
    # ADDED THESE TWO:
    "json-repair"
    "litellm"
  ];

  # Removed 'oauth-cli-kit' from this list since we are providing it now
  pythonRemoveDeps =[
    "dingtalk-stream"
    "lark-oapi"
    "mcp"
    "python-socketio"
    "python-telegram-bot"
    "qq-botpy"
    "readability-lxml"
    "slack-sdk"
    "slackify-markdown"
  ];

  doCheck = false;

  meta = with pkgs.lib; {
    description = "Ultra-lightweight AI agent framework";
    homepage = "https://github.com/HKUDS/nanobot";
    license = licenses.mit;
    mainProgram = "nanobot";
  };
}
