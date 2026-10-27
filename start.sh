#!/usr/bin/env bash
# ==============================================================================
# Skrypt uruchamiający Antigravity CLI w odizolowanym sandboxie macOS (Seatbelt)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SANDBOX_PROFILE="$SCRIPT_DIR/agent-sandbox.sb"

# 1. Sprawdzenie obecności profilu piaskownicy
if [[ ! -f "$SANDBOX_PROFILE" ]]; then
    echo "[-] Błąd: Nie znaleziono pliku profilu sandboxa: $SANDBOX_PROFILE" >&2
    exit 1
fi

# 2. Uzupełnienie zmiennej PATH o typowe lokalizacje instalacji Antigravity CLI
export PATH="$HOME/.gemini/antigravity/bin:$HOME/Library/Application Support/Antigravity/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# 3. Wyszukanie binarnego pliku agy / antigravity (można nadpisać przez env var AGY_BIN)
AGY_BIN="${AGY_BIN:-$(command -v agy 2>/dev/null || command -v antigravity 2>/dev/null || true)}"
if [[ -z "$AGY_BIN" ]]; then
    for candidate in \
        "$HOME/.gemini/antigravity/bin/agy" \
        "$HOME/.gemini/antigravity/bin/antigravity" \
        "$HOME/Library/Application Support/Antigravity/bin/agy" \
        "$HOME/Library/Application Support/Antigravity/bin/antigravity" \
        "/opt/homebrew/bin/agy" \
        "/usr/local/bin/agy"; do
        if [[ -x "$candidate" ]]; then
            AGY_BIN="$candidate"
            break
        fi
    done
    AGY_BIN="${AGY_BIN:-agy}"
fi

# 4. Sprawdzenie dostępności sandbox-exec
if ! command -v sandbox-exec >/dev/null 2>&1; then
    echo "[-] Błąd: Narzędzie 'sandbox-exec' nie jest dostępne w tym systemie." >&2
    exit 1
fi

# 5. Tryb inline: --here / -h — uruchomienie w bieżącej sesji terminala
if [[ "${1:-}" == "--here" || "${1:-}" == "-h" ]]; then
    shift
    echo "[+] Uruchamianie Antigravity CLI w sandboxie (bieżący terminal)..."
    echo "    Katalog projektu: $SCRIPT_DIR"
    echo "    Profil:           $SANDBOX_PROFILE"
    echo "    Polecenie:        $AGY_BIN"
    cd "$SCRIPT_DIR"
    exec sandbox-exec \
        -D PROJECT_DIR="$SCRIPT_DIR" \
        -D USER_HOME="$HOME" \
        -f "$SANDBOX_PROFILE" \
        "$AGY_BIN" "$@"
fi

# 6. Tryb domyślny: uruchomienie nowej sesji w aplikacji Terminal.app
echo "[+] Otwieranie nowego okna Terminal.app z sandboxem Antigravity CLI..."

# Budowanie polecenia dla Terminal.app — każdy argument cytowany przez printf '%q'
CMD="cd $(printf '%q' "$SCRIPT_DIR") && $(printf '%q' "$SCRIPT_DIR/start.sh") --here"
for arg in "$@"; do
    CMD="$CMD $(printf '%q' "$arg")"
done

osascript <<EOF
tell application "Terminal"
    activate
    do script "$CMD"
end tell
EOF

echo "[+] Terminal.app został otwarty pomyślnie."
