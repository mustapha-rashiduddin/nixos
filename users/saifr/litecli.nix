{ pkgs }:

pkgs.litecli.overridePythonAttrs (oldAttrs: {
  dependencies = (oldAttrs.dependencies or []) ++ [ pkgs.python3Packages.pyperclip ];

  postPatch = (oldAttrs.postPatch or "") + ''
    sed -i '/^from prompt_toolkit.shortcuts import PromptSession, CompleteStyle$/a from prompt_toolkit.clipboard.pyperclip import PyperclipClipboard' litecli/main.py
    sed -i 's/^                editing_mode=editing_mode,$/                editing_mode=editing_mode,\n                clipboard=PyperclipClipboard(),/' litecli/main.py
  '';
})