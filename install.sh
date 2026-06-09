#!/bin/sh
set -eu

REPO="delee03/DevTranslator"
BINARY_NAME="devtranslator"
DEFAULT_PREFIX="${HOME:-$PWD}/.local"
PREFIX="${PREFIX:-$DEFAULT_PREFIX}"
VERSION="latest"
FROM_SOURCE=0
UNINSTALL=0

usage() {
  cat <<EOF
DevTranslator installer

Usage:
  sh install.sh [options]

Options:
  --prefix PATH       Install under PATH/bin (default: \$HOME/.local)
  --version VERSION   Install a specific GitHub release tag (default: latest)
  --from-source       Build from the main branch with SwiftPM
  --uninstall         Remove the installed binary
  -h, --help          Show this help
EOF
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ "$#" -ge 2 ] || fail "--prefix requires a path"
      PREFIX="$2"
      shift 2
      ;;
    --version)
      [ "$#" -ge 2 ] || fail "--version requires a tag"
      VERSION="$2"
      shift 2
      ;;
    --from-source)
      FROM_SOURCE=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

INSTALL_DIR="$PREFIX/bin"
INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"

if [ "$UNINSTALL" -eq 1 ]; then
  if [ -x "$INSTALL_PATH" ]; then
    rm -f "$INSTALL_PATH" || fail "could not remove $INSTALL_PATH"
    log "Removed $INSTALL_PATH"
  else
    log "$BINARY_NAME is not installed at $INSTALL_PATH"
  fi
  exit 0
fi

case "$(uname -s)" in
  Darwin) ;;
  *) fail "DevTranslator currently supports macOS only" ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
  arm64|x86_64) ;;
  *) fail "unsupported architecture: $ARCH" ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

make_install_dir() {
  if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR" 2>/dev/null || fail "could not create $INSTALL_DIR; retry with --prefix \$HOME/.local"
  fi
  [ -w "$INSTALL_DIR" ] || fail "$INSTALL_DIR is not writable; retry with --prefix \$HOME/.local or run with sudo"
}

install_binary() {
  make_install_dir
  cp "$1" "$INSTALL_PATH"
  chmod 755 "$INSTALL_PATH"
  log "Installed $BINARY_NAME to $INSTALL_PATH"
}

install_from_release() {
  need_cmd curl
  ASSET="devtranslator-macos-$ARCH.tar.gz"
  if [ "$VERSION" = "latest" ]; then
    URL="https://github.com/$REPO/releases/latest/download/$ASSET"
  else
    URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET"
  fi

  ARCHIVE="$TMP_DIR/$ASSET"
  log "Downloading $URL"
  curl -fsSL "$URL" -o "$ARCHIVE"
  tar -xzf "$ARCHIVE" -C "$TMP_DIR"
  [ -x "$TMP_DIR/$BINARY_NAME" ] || fail "release archive did not contain $BINARY_NAME"
  install_binary "$TMP_DIR/$BINARY_NAME"
}

install_from_source() {
  need_cmd swift
  need_cmd git

  SRC="$TMP_DIR/source"
  log "Building DevTranslator from source"
  git clone --depth 1 "https://github.com/$REPO.git" "$SRC" >/dev/null 2>&1
  (cd "$SRC" && swift build -c release --disable-sandbox)

  BUILT="$SRC/.build/release/$BINARY_NAME"
  [ -x "$BUILT" ] || fail "SwiftPM did not produce $BUILT"
  install_binary "$BUILT"
}

if [ "$FROM_SOURCE" -eq 1 ]; then
  install_from_source
else
  if ! install_from_release; then
    log "Release binary is not available; falling back to source build."
    install_from_source
  fi
fi

if ! command -v "$BINARY_NAME" >/dev/null 2>&1; then
  cat <<EOF

Note: $INSTALL_DIR is not currently on PATH.
Add this to your shell profile:

  export PATH="$INSTALL_DIR:\$PATH"
EOF
fi

cat <<EOF

Next steps:
  $BINARY_NAME config --show
  $BINARY_NAME start

Accessibility permission is required for selection detection:
  System Settings -> Privacy & Security -> Accessibility
EOF
