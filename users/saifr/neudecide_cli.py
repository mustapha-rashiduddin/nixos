"""NeuDecide: speech + a list of tools -> tool calls.

The model is the q4 ONNX export that ships in the Nix store, so this runs
fully offline: no Hugging Face account, no token, no network.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def read_tools(path):
    text = Path(path).read_text(encoding="utf-8")
    tools = json.loads(text)
    if not isinstance(tools, list) or not tools:
        sys.exit(f"{path}: expected a non-empty JSON list of tool schemas")
    return tools


def record(seconds, rate=16000):
    arecord = shutil.which("arecord")
    if arecord is None:
        sys.exit("arecord not found; install alsa-utils or pass --audio FILE.wav")
    wav = Path(tempfile.mkdtemp(prefix="neudecide-")) / "mic.wav"
    print(f"recording {seconds}s from the default mic, say something now...", file=sys.stderr)
    subprocess.run(
        [
            arecord,
            "-q",
            "-f", "S16_LE",
            "-r", str(rate),
            "-c", "1",
            "-t", "wav",
            "-d", str(seconds),
            str(wav),
        ],
        check=True,
    )
    return wav


def main():
    p = argparse.ArgumentParser(
        prog="neudecide",
        description="Turn speech into tool calls. English, ~10 tools, 30s max.",
    )
    src = p.add_mutually_exclusive_group()
    src.add_argument("--audio", type=Path, help="16kHz/mono PCM WAV to run through the model")
    src.add_argument("--record", type=int, metavar="SECONDS", help="record from the mic first")
    src.add_argument("--demo", action="store_true", help="run the bundled 'clean the bathroom' clip")
    p.add_argument("--tools", type=Path, help="JSON list of tool schemas (default: the bundled vacuum tools)")
    p.add_argument("--model", type=Path, required=True, help="model directory (injected by the wrapper)")
    p.add_argument("--demo-audio", type=Path, help="bundled demo clip (injected by the wrapper)")
    p.add_argument("--default-tools", type=Path, help="bundled tool list (injected by the wrapper)")
    p.add_argument("--threads", type=int, default=1, help="ONNX Runtime threads (default: 1)")
    p.add_argument("--json", action="store_true", help="print raw JSON instead of a summary")
    args = p.parse_args()

    tools_path = args.tools or args.default_tools
    if not tools_path:
        sys.exit("no tool list: pass --tools FILE.json")
    tools = read_tools(tools_path)

    audio = args.audio
    if args.record:
        audio = record(args.record)
    elif not audio:
        if not args.demo_audio:
            sys.exit("nothing to run: pass --audio FILE.wav, --record SECONDS or --demo")
        audio = args.demo_audio
    if not audio.exists():
        sys.exit(f"{audio}: no such file")

    from neudecide import NeuDecide

    t0 = time.perf_counter()
    model = NeuDecide(str(args.model), threads=args.threads)
    load = time.perf_counter() - t0

    t0 = time.perf_counter()
    calls = model.generate(str(audio), tools)
    infer = time.perf_counter() - t0

    if args.json:
        print(json.dumps(calls, indent=2))
    elif not calls:
        print(f"no tool call ({load * 1000:.0f} ms load, {infer * 1000:.0f} ms run)")
    else:
        print(
            f"{load * 1000:.0f} ms load, {infer * 1000:.0f} ms run, {len(tools)} tools offered\n"
        )
        for call in calls:
            args_ = call.get("arguments") or {}
            rendered = " ".join(f"{k}={v!r}" for k, v in args_.items())
            print(f"  {call['name']}({rendered})")

    if os.environ.get("NEUDECIDE_DEBUG"):
        print(f"\nmodel:  {args.model}", file=sys.stderr)
        print(f"audio:  {audio}", file=sys.stderr)
        print(f"tools:  {tools_path}", file=sys.stderr)


if __name__ == "__main__":
    main()