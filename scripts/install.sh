#!/usr/bin/env bash
set -euo pipefail

REPO="wuyuxiangX/dingit"
BINARY="dingit"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo ""
echo -e "${CYAN}  ____  _             _ _   ${NC}"
echo -e "${CYAN} |  _ \\(_)_ __   __ _(_) |_ ${NC}"
echo -e "${CYAN} | | | | | '_ \\ / _\` | | __|${NC}"
echo -e "${CYAN} | |_| | | | | | (_| | | |_ ${NC}"
echo -e "${CYAN} |____/|_|_| |_|\\__, |_|\\__|${NC}"
echo -e "${CYAN}                |___/        ${NC}"
echo ""
echo -e "  CLI Installer"
echo ""

# ── Temp dir with cleanup ─────────────────────────────────────────────────
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# ── Detect download tool ──────────────────────────────────────────────────
# latest_tag() resolves https://github.com/$REPO/releases/latest to its
# redirect target and strips the tag off the URL's last segment. This
# avoids parsing the GitHub API JSON with grep/sed, which breaks when
# field order changes or values contain escaped quotes. Both curl and
# wget report the final URL; we pick whichever is available.
if command -v curl &>/dev/null; then
  fetch()    { curl -fsSL "$1"; }
  download() { curl -fsSL -o "$2" "$1"; }
  latest_tag() {
    local url
    url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
      "https://github.com/${REPO}/releases/latest") || return 1
    echo "${url##*/}"
  }
elif command -v wget &>/dev/null; then
  fetch()    { wget -qO- "$1"; }
  download() { wget -qO "$2" "$1"; }
  latest_tag() {
    local url
    url=$(wget --max-redirect=10 --method=HEAD -q -S \
      "https://github.com/${REPO}/releases/latest" 2>&1 \
      | awk '/^[[:space:]]*Location: /{loc=$2} END{print loc}') || return 1
    echo "${url##*/}"
  }
else
  fail "curl or wget is required but not found"
fi

# ── Detect OS ─────────────────────────────────────────────────────────────
OS=$(uname -s)
case "$OS" in
  Linux)  OS="linux" ;;
  Darwin) OS="darwin" ;;
  *)      fail "Unsupported OS: $OS (supported: Linux, macOS)" ;;
esac

# ── Detect architecture ──────────────────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)            fail "Unsupported architecture: $ARCH (supported: amd64, arm64)" ;;
esac

ok "Detected ${OS}/${ARCH}"

# ── Determine version ────────────────────────────────────────────────────
if [ -n "${DINGIT_VERSION:-}" ]; then
  VERSION="$DINGIT_VERSION"
  info "Using specified version: $VERSION"
else
  info "Fetching latest release..."
  VERSION=$(latest_tag || true)
  if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
    fail "Could not determine latest version. Set DINGIT_VERSION manually."
  fi
  ok "Latest version: $VERSION"
fi

# ── Download tarball + checksums ─────────────────────────────────────────
TARBALL="${BINARY}-${OS}-${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

info "Downloading ${TARBALL}..."
download "${BASE_URL}/${TARBALL}" "${WORK_DIR}/${TARBALL}"
download "${BASE_URL}/SHA256SUMS" "${WORK_DIR}/SHA256SUMS"
ok "Download complete"

# ── SHA256 verification ──────────────────────────────────────────────────
info "Verifying checksum..."
EXPECTED=$(grep "${TARBALL}" "${WORK_DIR}/SHA256SUMS" | awk '{print $1}')
if [ -z "$EXPECTED" ]; then
  fail "Tarball ${TARBALL} not found in SHA256SUMS"
fi

if command -v sha256sum &>/dev/null; then
  ACTUAL=$(sha256sum "${WORK_DIR}/${TARBALL}" | awk '{print $1}')
elif command -v shasum &>/dev/null; then
  ACTUAL=$(shasum -a 256 "${WORK_DIR}/${TARBALL}" | awk '{print $1}')
else
  fail "sha256sum or shasum is required for checksum verification"
fi

if [ "$EXPECTED" != "$ACTUAL" ]; then
  fail "SHA256 checksum mismatch!\n  Expected: ${EXPECTED}\n  Actual:   ${ACTUAL}"
fi
ok "Checksum verified"

# ── Extract binary ───────────────────────────────────────────────────────
tar xzf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
chmod +x "${WORK_DIR}/${BINARY}"

# ── Determine install location ───────────────────────────────────────────
if [ -n "${DINGIT_INSTALL_DIR:-}" ]; then
  INSTALL_DIR="$DINGIT_INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
elif [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
  INSTALL_DIR="$HOME/.local/bin"
else
  INSTALL_DIR="/usr/local/bin"
  if [ ! -w "$INSTALL_DIR" ]; then
    info "Installing to ${INSTALL_DIR} (requires sudo)..."
    sudo mkdir -p "$INSTALL_DIR"
  fi
fi

if [ -w "$INSTALL_DIR" ]; then
  mv "${WORK_DIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
else
  sudo mv "${WORK_DIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
fi
ok "Installed to ${INSTALL_DIR}/${BINARY}"

# ── Verify installation ─────────────────────────────────────────────────
echo ""

# Check if install dir is in PATH
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    warn "${INSTALL_DIR} is not in your PATH"
    echo ""
    echo -e "  Add it to your shell profile:"
    echo -e "    ${CYAN}export PATH=\"${INSTALL_DIR}:\$PATH\"${NC}"
    echo ""
    ;;
esac

if command -v ${BINARY} &>/dev/null; then
  info "Verifying installation..."
  ${BINARY} version
  echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  dingit installed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Get started:"
echo -e "    ${CYAN}dingit config set server_url https://your-server:8080${NC}"
echo -e "    ${CYAN}dingit config set api_key your-api-key${NC}"
echo -e "    ${CYAN}dingit send -t 'Hello' -b 'World'${NC}"
echo ""
