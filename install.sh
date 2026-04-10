#!/usr/bin/env bash
#
# codebase-rizz installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nguyenhoangminh1106/codebase-rizz/main/install.sh | bash
#
# What it does:
#   1. Downloads the latest codebase-rizz skill from GitHub (tarball, no git required)
#   2. Installs it to ~/.claude/skills/codebase-rizz
#   3. Creates the global data directory ~/.codebase-rizz with an empty registry.json
#   4. Prints next steps
#
# Re-running is safe — it will upgrade the skill in place without touching your data.

set -euo pipefail

REPO="nguyenhoangminh1106/codebase-rizz"
BRANCH="${CODEBASE_RIZZ_BRANCH:-main}"
SKILL_SRC_SUBPATH="skills/codebase-rizz"
SKILL_DEST="${HOME}/.claude/skills/codebase-rizz"
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

if ! command -v curl >/dev/null 2>&1; then
  error "curl is required but not installed."
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  error "tar is required but not installed."
  exit 1
fi

# --- download skill ----------------------------------------------------------

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
  error "Could not find extracted skill directory in tarball."
  exit 1
fi

SKILL_SRC="${EXTRACTED_DIR}/${SKILL_SRC_SUBPATH}"
if [ ! -f "${SKILL_SRC}/SKILL.md" ]; then
  error "Skill source not found at ${SKILL_SRC}/SKILL.md. The repo layout may have changed."
  exit 1
fi

# --- install skill -----------------------------------------------------------

info "Installing skill to ${SKILL_DEST}..."

mkdir -p "$(dirname "${SKILL_DEST}")"

if [ -d "${SKILL_DEST}" ]; then
  warn "Existing install found — upgrading in place (your data in ${DATA_DIR} is not touched)."
  rm -rf "${SKILL_DEST}"
fi

cp -R "${SKILL_SRC}" "${SKILL_DEST}"
success "Skill installed."

# --- create data directory ---------------------------------------------------

info "Setting up data directory at ${DATA_DIR}..."

mkdir -p "${DATA_DIR}/repos"

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

# --- done --------------------------------------------------------------------

echo
success "codebase-rizz installed."
echo
echo "Next steps:"
echo "  1. cd into any repo you want to track"
echo "  2. In Claude Code, run: /codebase-rizz bootstrap"
echo "  3. Pick global or repo-local storage when prompted"
echo
echo "Data directory:  ${DATA_DIR}"
echo "Skill directory: ${SKILL_DEST}"
echo
