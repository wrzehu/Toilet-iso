#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Skrypt uruchamiający Antigravity CLI w odizolowanym sandboxie macOS (Seatbelt)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_PROFILE="$SCRIPT_DIR/agent-sandbox.sb"

if [[ ! -f "$SANDBOX_PROFILE" ]]; then
    echo "[-] Błąd: Nie znaleziono pliku profilu sandboxa: $SANDBOX_PROFILE" >&2
    exit 1
fi

# Wykrycie binarnej ścieżki do agy / antigravity cli
AGY_BIN="${AGY_BIN:-$(command -v agy || true)}"
if [[ -z "$AGY_BIN" ]]; then
    if [[ -x "$HOME/.gemini/antigravity/bin/agy" ]]; then
        AGY_BIN="$HOME/.gemini/antigravity/bin/agy"
    elif [[ -x "/usr/local/bin/agy" ]]; then
        AGY_BIN="/usr/local/bin/agy"
    elif [[ -x "/opt/homebrew/bin/agy" ]]; then
        AGY_BIN="/opt/homebrew/bin/agy"
    else
        AGY_BIN="agy"
    fi
fi

# Sprawdzenie trybu uruchomienia:
# Domyślnie: otwiera nowe okno w Terminal.app (zgodnie z preferencjami)
# Opcjonalnie: flaga --here / -h uruchamia w bieżącej sesji terminala
LAUNCH_IN_PLACE=false
if [[ "${1:-}" == "--here" || "${1:-}" == "-h" ]]; then
    LAUNCH_IN_PLACE=true
    shift
fi

if [[ "$LAUNCH_IN_PLACE" == true ]]; then
    echo "[+] Uruchamianie Antigravity CLI w sandboxie (bieżący terminal)..."
    cd "$SCRIPT_DIR"
    exec sandbox-exec -D PROJECT_DIR="$SCRIPT_DIR" -D USER_HOME="$HOME" -f "$SANDBOX_PROFILE" "$AGY_BIN" "$@"
else
    echo "[+] Otwieranie nowego okna Terminal.app z sandboxem Antigravity CLI..."
    # Budujemy komendę do wykonania w nowym oknie
    CMD_STR="cd \"$SCRIPT_DIR\" && sandbox-exec -D PROJECT_DIR=\"$SCRIPT_DIR\" -D USER_HOME=\"$HOME\" -f \"$SANDBOX_PROFILE\" \"$AGY_BIN\""
    if [[ $# -gt 0 ]]; then
        CMD_STR="$CMD_STR \"$*\""
    fi

    osascript <<EOF
tell application "Terminal"
    activate
    do script "$CMD_STR"
end tell
EOF
    echo "[+] Terminal.app został otwarty pomyślnie."
fi
