{ pkgs }:

pkgs.litecli.overridePythonAttrs (oldAttrs: {
  dependencies = (oldAttrs.dependencies or []) ++ [ pkgs.python3Packages.pyperclip ];

  postPatch = (oldAttrs.postPatch or "") + ''
    sed -i '/^from prompt_toolkit.shortcuts import PromptSession, CompleteStyle$/a from prompt_toolkit.clipboard.pyperclip import PyperclipClipboard' litecli/main.py
    sed -i 's/^                editing_mode=editing_mode,$/                editing_mode=editing_mode,\n                clipboard=PyperclipClipboard(),/' litecli/main.py
    # Drop -F from the default LESS flags. litecli only sends results to the
    # pager once they exceed (screen height minus its reserved prompt/toolbar
    # margin), but with -F, less then auto-quits and dumps the entire result
    # whenever it still fits within the raw terminal height. Result sets in
    # that band got printed like a plain CLI instead of a scrollable pager
    # (recurring complaint in st, a short 24-row terminal). -RX keeps the
    # color + no-clear-screen behavior but always lets less page/scroll.
    sed -i 's/os.environ\["LESS"\] = "-RXF"/os.environ["LESS"] = "-RX"/' litecli/main.py
  '';
})