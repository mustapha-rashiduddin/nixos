#!/usr/bin/env python3
"""jev - ask Jev (TypeSafe System One) typed questions about some state.

Examples:
  jev --text "I was charged twice, fix it ASAP" --noul "Does this express urgency?"
  jev --file ticket.txt --choice '{"instructions":"Which team?","criteria":{"billing":"charges","tech":"bugs"}}'
  jev --file ticket.txt --score '{"instructions":"How frustrated?","criteria":["calm","annoyed","furious"]}'
  cat ticket.txt | jev --questions questions.json
  jev --list-models
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from typesafe_sdk import TypeSafeClient, TypeSafeError

CRITERIA_HINT = {
    "choice": '{"instructions": "...", "criteria": {"option": "description", ...}}',
    "score": '{"instructions": "...", "criteria": ["low", "medium", "high"]}',
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="jev",
        description="Send state and typed questions to Jev, print the answers as JSON.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "state (exactly one, or pipe on stdin):\n"
            "  --text TEXT            state as a plain string\n"
            "  --file PATH            state from a file ('-' for stdin)\n"
            "  --state-json JSON      state as a JSON object or array\n"
            "\n"
            "questions (repeatable, all evaluated in one parallel call):\n"
            "  --noul QUESTION        yes/no question, answered with a 0-1 probability\n"
            f"  --choice JSON          {CRITERIA_HINT['choice']}\n"
            f"  --score JSON           {CRITERIA_HINT['score']}\n"
            "  --questions PATH       JSON object of name -> question, merged with the above\n"
            "\n"
            "auth: TYPESAFE_API_KEY (get one at https://console.typesafe.ai/keys)"
        ),
    )
    state = parser.add_mutually_exclusive_group()
    state.add_argument("--text", help="state as a plain string")
    state.add_argument("--file", help="read state from a file, or '-' for stdin")
    state.add_argument("--state-json", help="state as a JSON object or array")
    parser.add_argument("--noul", action="append", metavar="QUESTION", help="yes/no question")
    parser.add_argument("--choice", action="append", metavar="JSON", help="choice question")
    parser.add_argument("--score", action="append", metavar="JSON", help="score question")
    parser.add_argument("--questions", metavar="PATH", help="JSON file of named questions")
    parser.add_argument("--model", default=None, help="model name (default: jev-latest)")
    parser.add_argument(
        "--base-url",
        default=None,
        help="API root to call (default: TypeSafe, or OpenRouter when its key is the one on file)",
    )
    parser.add_argument("--timeout", type=float, default=None, help="per-request timeout in seconds (default: 10)")
    parser.add_argument("--compact", action="store_true", help="print single-line JSON")
    parser.add_argument("--answers", action="store_true", help="print only the answers object")
    parser.add_argument("--list-models", action="store_true", help="list models available to the account and exit")
    return parser.parse_args()


def read_state(args: argparse.Namespace) -> Any:
    if args.text is not None:
        return args.text
    if args.state_json is not None:
        return parse_json(args.state_json, "--state-json")
    if args.file is not None:
        if args.file == "-":
            return sys.stdin.read()
        return read_file(args.file)
    if not sys.stdin.isatty():
        return sys.stdin.read()
    raise SystemExit("jev: no state given; use --text, --file, --state-json, or pipe state on stdin")


def read_file(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError as error:
        raise SystemExit(f"jev: cannot read {path}: {error.strerror}") from error


def parse_json(value: str, flag: str) -> Any:
    try:
        return json.loads(value)
    except json.JSONDecodeError as error:
        raise SystemExit(f"jev: {flag} is not valid JSON: {error}") from error


def add_question(questions: dict[str, Any], prefix: str, question: dict[str, Any]) -> None:
    index = 1
    while f"{prefix}{index}" in questions:
        index += 1
    questions[f"{prefix}{index}"] = question


def build_questions(args: argparse.Namespace) -> dict[str, Any]:
    questions: dict[str, Any] = {}
    if args.questions:
        loaded = parse_json(read_file(args.questions), args.questions)
        if not isinstance(loaded, dict):
            raise SystemExit(f"jev: {args.questions} must contain a JSON object of name -> question")
        questions.update(loaded)
    for question in args.noul or []:
        add_question(questions, "noul", {"type": "noul", "instructions": question})
    for kind, specs in (("choice", args.choice), ("score", args.score)):
        for spec in specs or []:
            parsed = parse_json(spec, f"--{kind}")
            if not isinstance(parsed, dict):
                raise SystemExit(f"jev: --{kind} needs a JSON object, got {type(parsed).__name__}")
            if "criteria" not in parsed:
                raise SystemExit(f"jev: --{kind} needs criteria: {CRITERIA_HINT[kind]}")
            if kind == "choice" and not isinstance(parsed["criteria"], dict):
                raise SystemExit("jev: --choice criteria must be an object of option -> description")
            if kind == "score" and not isinstance(parsed["criteria"], list):
                raise SystemExit("jev: --score criteria must be a list of rubric levels")
            add_question(questions, kind, {"type": kind, **parsed})
    if not questions:
        raise SystemExit("jev: no questions given; use --noul, --choice, --score, or --questions")
    return questions


KEY_SOURCES = {
    "typesafe": ("typesafe/api_key", None),
    "openrouter": ("openrouter/api_key", "https://openrouter.ai/api"),
}


def resolve_credentials() -> tuple[str, str | None]:
    """Return an API key and the base URL it belongs to.

    An explicit TYPESAFE_API_KEY always wins and keeps whatever TYPESAFE_BASE_URL
    says. Otherwise the sops-managed key files are tried in order, each with the
    base URL that serves it.
    """
    base_url_override = os.environ.get("TYPESAFE_BASE_URL", "").strip()
    key = os.environ.get("TYPESAFE_API_KEY", "").strip()
    if key:
        return key, base_url_override or None

    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    for relative_path, base_url in KEY_SOURCES.values():
        try:
            stored = (config_home / relative_path).read_text(encoding="utf-8").strip()
        except OSError:
            continue
        if stored:
            return stored, base_url_override or base_url
    return "", base_url_override or None


def main() -> int:
    args = parse_args()

    key, base_url = resolve_credentials()
    if not key:
        wanted = " or ".join(str(Path.home() / ".config" / path) for path, _ in KEY_SOURCES.values())
        print(
            f"jev: no API key; set TYPESAFE_API_KEY or write one to {wanted}"
            " (keys: https://console.typesafe.ai/keys, https://openrouter.ai/settings/keys)",
            file=sys.stderr,
        )
        return 2
    os.environ["TYPESAFE_API_KEY"] = key

    try:
        with TypeSafeClient(base_url=args.base_url or base_url, model=args.model, timeout=args.timeout) as client:
            if args.list_models:
                payload: Any = client.models.list().model_dump(mode="json")
            else:
                response = client.system_one(state=read_state(args), questions=build_questions(args))
                payload = response.model_dump(mode="json")
                if args.answers:
                    payload = payload.get("answers", {})
    except TypeSafeError as error:
        print(f"jev: {error}", file=sys.stderr)
        endpoint = args.base_url or base_url
        if endpoint and "typesafe.ai" not in endpoint:
            print(
                f"jev: {endpoint} does not serve TypeSafe's /v1/models shape;"
                " browse https://openrouter.ai/typesafe instead",
                file=sys.stderr,
            )
        return 1

    json.dump(payload, sys.stdout, indent=None if args.compact else 2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
