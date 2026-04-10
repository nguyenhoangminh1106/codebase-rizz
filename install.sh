#!/usr/bin/env bash
#
# codebase-rizz fallback installer
#
# The recommended install path is via the Claude Code plugin system:
#
#   /plugin install codebase-rizz@nguyenhoangminh1106
#
# This script is a fallback for users who want to install without the plugin
# system, or want to try a branch of the repo without publishing it.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nguyenhoangminh1106/codebase-rizz/main/install.sh | bash
#
# What it does:
#   1. Downloads the latest codebase-rizz plugin from GitHub (tarball, no git required)
#   2. Installs it to ~/.claude/plugins/codebase-rizz
#   3. Creates the global data directory ~/.codebase-rizz with an empty registry.json
#   4. Prints next steps
#
# Re-running is safe — it upgrades the plugin in place without touching your data.

set -euo pipefail

REPO="nguyenhoangminh1106/codebase-rizz"
BRANCH="${CODEBASE_RIZZ_BRANCH:-main}"
PLUGIN_DEST="${HOME}/.claude/plugins/codebase-rizz"
DATA_DIR="${HOME}/.codebase-rizz"
REGISTRY="${DATA_DIR}/registry.json"

color_blue='\033[0;34m'
color_green='\033[0;32m'
color_yellow='\033[0;33m'
color_red='\033[0;31m'
color_reset='\033[0m'

info()    { printf "${color_blue}▸${color_reset} %s\n" "$1"; }
success() { printf "${color_green}✓${color_reset} %s\n" "$1"; }
warn()    { printf "${color_yellow}!${color_reset} %s\n" "$1"; }
error()   { printf "${color_red}✗${color_reset} %s\n" "$1" >&2; }

# --- preflight ---------------------------------------------------------------

OS="$(uname -s)"
if [ "${OS}" != "Darwin" ] && [ "${CODEBASE_RIZZ_FORCE:-0}" != "1" ]; then
  error "codebase-rizz is macOS-only in the current release."
  echo
  echo "The learning crons rely on launchd, which only exists on macOS."
  echo "Linux (crontab/systemd) and Windows (Task Scheduler) support is planned."
  echo
  echo "If you want to try it anyway and wire up crons manually, set CODEBASE_RIZZ_FORCE=1 and re-run:"
  echo "  CODEBASE_RIZZ_FORCE=1 curl -fsSL ... | bash"
  echo
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  error "curl is required but not installed."
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  error "tar is required but not installed."
  exit 1
fi

# --- download plugin ---------------------------------------------------------

info "Downloading codebase-rizz from ${REPO}@${BRANCH}..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TARBALL_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"
if ! curl -fsSL "${TARBALL_URL}" -o "${TMP_DIR}/codebase-rizz.tar.gz"; then
  error "Download failed. Check your network connection and that the repo exists."
  exit 1
fi

tar -xzf "${TMP_DIR}/codebase-rizz.tar.gz" -C "${TMP_DIR}"

# GitHub names the extracted dir <repo-name>-<branch>
EXTRACTED_DIR="$(find "${TMP_DIR}" -maxdepth 1 -type d -name 'codebase-rizz-*' | head -n 1)"
if [ -z "${EXTRACTED_DIR}" ]; then
  error "Could not find extracted plugin directory in tarball."
  exit 1
fi

# Validate the extracted content has the plugin.json at root and skills/ dir
if [ ! -f "${EXTRACTED_DIR}/plugin.json" ]; then
  error "plugin.json not found in extracted tarball. The repo layout may have changed."
  exit 1
fi

if [ ! -d "${EXTRACTED_DIR}/skills" ]; then
  error "skills/ directory not found in extracted tarball. The repo layout may have changed."
  exit 1
fi

# --- install plugin ----------------------------------------------------------

info "Installing plugin to ${PLUGIN_DEST}..."

mkdir -p "$(dirname "${PLUGIN_DEST}")"

if [ -d "${PLUGIN_DEST}" ]; then
  warn "Existing install found — upgrading in place (your data in ${DATA_DIR} is not touched)."
  rm -rf "${PLUGIN_DEST}"
fi

mkdir -p "${PLUGIN_DEST}"

# Copy the parts of the repo that make up the plugin: plugin.json, skills/,
# CHANGELOG.md, README.md, LICENSE. Leave install.sh and .git behind.
cp "${EXTRACTED_DIR}/plugin.json" "${PLUGIN_DEST}/plugin.json"
cp -R "${EXTRACTED_DIR}/skills" "${PLUGIN_DEST}/skills"

if [ -f "${EXTRACTED_DIR}/CHANGELOG.md" ]; then
  cp "${EXTRACTED_DIR}/CHANGELOG.md" "${PLUGIN_DEST}/CHANGELOG.md"
fi

if [ -f "${EXTRACTED_DIR}/README.md" ]; then
  cp "${EXTRACTED_DIR}/README.md" "${PLUGIN_DEST}/README.md"
fi

if [ -f "${EXTRACTED_DIR}/LICENSE" ]; then
  cp "${EXTRACTED_DIR}/LICENSE" "${PLUGIN_DEST}/LICENSE"
fi

success "Plugin installed."

# --- create data directory ---------------------------------------------------

info "Setting up data directory at ${DATA_DIR}..."

mkdir -p "${DATA_DIR}/repos"
mkdir -p "${DATA_DIR}/logs"

if [ ! -f "${REGISTRY}" ]; then
  cat > "${REGISTRY}" <<'EOF'
{
  "version": 1,
  "repos": []
}
EOF
  success "Created empty registry at ${REGISTRY}."
else
  success "Existing registry preserved at ${REGISTRY}."
fi

# --- upgrade hint ------------------------------------------------------------

# If the user already has repos in the registry, this is an upgrade, not a
# fresh install. Tell them about the upgrade skill so they can opt into new
# features.

EXISTING_REPOS=0
if [ -f "${REGISTRY}" ]; then
  EXISTING_REPOS="$(grep -c '"path":' "${REGISTRY}" 2>/dev/null || echo 0)"
fi

# --- done --------------------------------------------------------------------

echo
success "codebase-rizz installed."
echo

warn "Heads up — the recommended install path is the plugin system:"
echo "  /plugin install codebase-rizz@nguyenhoangminh1106"
echo
echo "This script is a fallback and may not be picked up by Claude Code's plugin"
echo "discovery in every version. If /codebase-rizz:bootstrap doesn't show up after"
echo "restarting Claude Code, switch to the /plugin install path above."
echo

if [ "${EXISTING_REPOS}" -gt 0 ]; then
  warn "You have ${EXISTING_REPOS} repo(s) already set up from a previous install."
  echo
  echo "To opt into new features from the newer version, run inside any tracked repo:"
  echo "  /codebase-rizz:upgrade"
  echo
  echo "See CHANGELOG.md at ${PLUGIN_DEST}/CHANGELOG.md for details."
  echo
else
  echo "Next steps:"
  echo "  1. cd into any repo you want to track"
  echo "  2. In Claude Code, run:  /codebase-rizz:bootstrap"
  echo "  3. Pick global or repo-local storage when prompted"
  echo
fi

echo "Data directory:   ${DATA_DIR}"
echo "Plugin directory: ${PLUGIN_DEST}"
echo
