#!/usr/bin/env bash
set -euo pipefail

REPO="wuyuxiangX/dingit"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/deploy"
INSTALL_DIR="dingit"

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
echo -e "  Interactive Notification System"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
  fail "Docker is not installed. Install it first: https://docs.docker.com/get-docker/"
fi

# Check Docker Compose
if docker compose version &>/dev/null; then
  COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
else
  fail "Docker Compose is not installed. Install it first: https://docs.docker.com/compose/install/"
fi

ok "Docker and Docker Compose detected"

# Check if directory exists
if [ -d "$INSTALL_DIR" ]; then
  warn "Directory '${INSTALL_DIR}' already exists"
  read -rp "  Overwrite config? (y/N) " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    info "Aborted"
    exit 0
  fi
fi

# Create directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download docker-compose.yml
info "Downloading docker-compose.yml..."
curl -fsSL "${BASE_URL}/docker-compose.yml" -o docker-compose.yml
ok "docker-compose.yml downloaded"

# Generate random password
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
DINGIT_API_KEY=$(openssl rand -hex 16)

# Write .env
cat > .env <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
DINGIT_API_KEY=${DINGIT_API_KEY}
PORT=8080
EOF
ok ".env created with random credentials"

# Start services
info "Starting Dingit..."
$COMPOSE up -d

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Dingit is running!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  URL:      ${CYAN}http://localhost:8080${NC}"
echo -e "  API Key:  ${CYAN}${DINGIT_API_KEY}${NC}"
echo -e "  Health:   ${CYAN}http://localhost:8080/health${NC}"
echo ""
echo -e "  Config:   ${YELLOW}$(pwd)/.env${NC}"
echo ""
echo -e "  Commands:"
echo -e "    Stop:    cd ${INSTALL_DIR} && ${COMPOSE} down"
echo -e "    Logs:    cd ${INSTALL_DIR} && ${COMPOSE} logs -f"
echo -e "    Update:  cd ${INSTALL_DIR} && ${COMPOSE} pull && ${COMPOSE} up -d"
echo ""
