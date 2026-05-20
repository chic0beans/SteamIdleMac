#!/bin/bash
# First-time GitHub setup for chic0beans — run once.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Make sure gh is on PATH (installed without Homebrew goes in ~/bin)
export PATH="$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

bash "$ROOT/scripts/install-tools.sh"

source "$ROOT/scripts/github-config.sh" 2>/dev/null || true
GITHUB_USER="${GITHUB_USER:-chic0beans}"
GITHUB_REPO="${GITHUB_REPO:-SteamIdleMac}"

echo ""
echo "=== Steam Idle Mac — GitHub setup ==="
echo "Account: $GITHUB_USER"
echo "Repo:    $GITHUB_REPO"
echo ""

if ! command -v gh >/dev/null 2>&1; then
    echo "Could not find 'gh'. Run:  bash scripts/install-tools.sh"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "Log in to GitHub (browser will open)..."
    echo "Sign in as: $GITHUB_USER"
    gh auth login
fi

echo "Logged in as: $(gh api user -q .login 2>/dev/null || echo unknown)"
echo ""

if [ ! -d .git ]; then
    git init
    git branch -M main
fi

git add -A
echo ""

if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "Steam Idle Mac"
elif ! git rev-parse HEAD >/dev/null 2>&1; then
    git commit --allow-empty -m "Steam Idle Mac"
else
    echo "Nothing new to commit."
fi

REMOTE="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"

if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "$REMOTE"
fi

if gh repo view "${GITHUB_USER}/${GITHUB_REPO}" >/dev/null 2>&1; then
    echo "Repo already exists on GitHub."
    git push -u origin main || git push origin main
else
    echo "Creating repo ${GITHUB_USER}/${GITHUB_REPO} on GitHub..."
    gh repo create "${GITHUB_REPO}" --public --source=. --remote=origin --push
fi

echo ""
echo "Done! Your code is on GitHub:"
echo "  https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo ""
echo "Next — upload a download for people:"
echo "  bash scripts/publish.sh"
echo ""
