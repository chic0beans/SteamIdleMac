#!/bin/bash
# Install GitHub CLI (gh) without needing Homebrew.
set -euo pipefail

export PATH="$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if command -v gh >/dev/null 2>&1; then
    echo "gh already installed: $(gh --version | head -1)"
    exit 0
fi

echo "Installing GitHub CLI (gh) into ~/bin ..."

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ARCH_TAG="macOS_arm64"
else
    ARCH_TAG="macOS_amd64"
fi

TAG=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
VER="${TAG#v}"
ZIP="gh_${VER}_${ARCH_TAG}.zip"
URL="https://github.com/cli/cli/releases/download/${TAG}/${ZIP}"

mkdir -p "$HOME/bin"
TMP=$(mktemp -d)
curl -fsSL "$URL" -o "$TMP/gh.zip"
unzip -o -q "$TMP/gh.zip" -d "$TMP/extract"
cp "$TMP/extract"/gh_*/bin/gh "$HOME/bin/gh"
chmod +x "$HOME/bin/gh"
rm -rf "$TMP"

# Add ~/bin to PATH permanently if missing
if ! grep -q 'export PATH="$HOME/bin' "$HOME/.zprofile" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zprofile"
fi
if ! grep -q 'export PATH="$HOME/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
fi

export PATH="$HOME/bin:$PATH"
echo "Installed: $(gh --version | head -1)"
echo ""
echo "Now run:  gh auth login"
echo "  (pick: GitHub.com → HTTPS → Login with a web browser)"
