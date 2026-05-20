#!/usr/bin/env bash
# claudenv installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh | bash
#   CLAUDENV_VERSION=v0.1.0 curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/v0.1.0/install.sh | bash

set -e

CLAUDENV_DIR="${CLAUDENV_DIR:-$HOME/.claudenv}"
CLAUDENV_VERSION="${CLAUDENV_VERSION:-main}"
CLAUDENV_REPO="${CLAUDENV_REPO:-bodasooqa/claudenv}"
CLAUDENV_SOURCE="https://raw.githubusercontent.com/$CLAUDENV_REPO/$CLAUDENV_VERSION/claudenv.sh"

# --- output helpers ---------------------------------------------------------

if [ -t 1 ]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
fi

info() { printf "${GREEN}==>${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}warn:${NC} %s\n" "$1" >&2; }
err()  { printf "${RED}error:${NC} %s\n" "$1" >&2; }

# --- detect downloader ------------------------------------------------------

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO- "$1"; }
else
  err "Need curl or wget to install"
  exit 1
fi

# --- download ---------------------------------------------------------------

info "Installing claudenv ($CLAUDENV_VERSION) to $CLAUDENV_DIR"
mkdir -p "$CLAUDENV_DIR"

tmp="$CLAUDENV_DIR/claudenv.sh.tmp"
if ! fetch "$CLAUDENV_SOURCE" > "$tmp"; then
  err "Failed to download $CLAUDENV_SOURCE"
  rm -f "$tmp"
  exit 1
fi

if [ ! -s "$tmp" ] || ! head -n 10 "$tmp" | grep -q "claudenv"; then
  err "Downloaded file doesn't look like claudenv.sh"
  rm -f "$tmp"
  exit 1
fi

mv "$tmp" "$CLAUDENV_DIR/claudenv.sh"
info "Saved $CLAUDENV_DIR/claudenv.sh"

# --- detect shell rc file ---------------------------------------------------

detect_rc() {
  local shell_name
  shell_name=$(basename "${SHELL:-/bin/bash}")
  case "$shell_name" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash)
      if [ -f "$HOME/.bashrc" ]; then
        echo "$HOME/.bashrc"
      elif [ -f "$HOME/.bash_profile" ]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    *) echo "" ;;
  esac
}

RC_FILE=$(detect_rc)
SOURCE_LINE="[ -s \"$CLAUDENV_DIR/claudenv.sh\" ] && source \"$CLAUDENV_DIR/claudenv.sh\"  # claudenv"

# --- wire into shell rc -----------------------------------------------------

if [ -z "$RC_FILE" ]; then
  warn "Couldn't detect your shell. Add this line manually to your shell rc:"
  echo "  $SOURCE_LINE"
elif grep -Fq "$CLAUDENV_DIR/claudenv.sh" "$RC_FILE" 2>/dev/null; then
  info "Source line already present in $RC_FILE"
else
  printf "\n%s\n" "$SOURCE_LINE" >> "$RC_FILE"
  info "Added source line to $RC_FILE"
fi

# --- check for claude CLI ---------------------------------------------------

if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI not found on PATH."
  warn "Install Claude Code first: https://docs.claude.com/en/docs/claude-code"
fi

# --- next steps -------------------------------------------------------------

cat <<EOF

${BOLD}${GREEN}claudenv installed.${NC}

To start using it in this terminal:
  ${BOLD}source $CLAUDENV_DIR/claudenv.sh${NC}

Or open a new terminal. Then try:
  claudenv import default          # save current ~/.claude as 'default'
  claudenv add work                # create a new account slot
  claudenv use work                # switch + set as global default

Optional (auto-switch on cd into a folder with .claudenvrc):
  echo 'claudenv_enable_auto_switch' >> $RC_FILE

EOF
