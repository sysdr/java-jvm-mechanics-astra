#!/usr/bin/env bash
# AstraKV Day-1 cleanup: remove git-unfriendly artifacts, scrub secrets,
# and prune unused Docker resources when Docker is available.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}=== AstraKV cleanup ===${NC}"

# --- 1) Remove build / OS / editor junk not useful for git push ---
echo -e "\n${CYAN}[1/4] Removing local build artifacts and junk files...${NC}"

REMOVED=0
remove_path() {
  local path="$1"
  if [ -e "$path" ]; then
    rm -rf "$path"
    echo "  removed: $path"
    REMOVED=$((REMOVED + 1))
  fi
}

remove_path "bin"
remove_path "out"
remove_path "target"
remove_path "build"
remove_path ".idea"
shopt -s nullglob
for iml in *.iml; do remove_path "$iml"; done
shopt -u nullglob

# Class files outside bin/, logs, OS junk, editor swap files
while IFS= read -r -d '' f; do
  rm -f "$f"
  echo "  removed: $f"
  REMOVED=$((REMOVED + 1))
done < <(find . -type f \( \
  -name '*.class' -o \
  -name '*.log' -o \
  -name '*.tmp' -o \
  -name '*~' -o \
  -name '*.swp' -o \
  -name '*.swo' -o \
  -name '.DS_Store' -o \
  -name 'Thumbs.db' \
\) ! -path './.git/*' -print0 2>/dev/null || true)

if [ "$REMOVED" -eq 0 ]; then
  echo "  nothing to remove"
else
  echo -e "${GREEN}✔ Removed $REMOVED path(s)${NC}"
fi

# --- 2) Scrub API keys / secret files ---
echo -e "\n${CYAN}[2/4] Checking for API keys and secret files...${NC}"

SECRET_REMOVED=0
for f in .env .env.local .env.production credentials.json service-account.json secrets.json; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo -e "  ${YELLOW}removed secret file: $f${NC}"
    SECRET_REMOVED=$((SECRET_REMOVED + 1))
  fi
done

# Soft scan of tracked-ish source/scripts (report only; do not rewrite source blindly)
MATCHES="$(grep -RInE \
  --exclude-dir=bin \
  --exclude-dir=.git \
  --exclude='cleanup.sh' \
  --exclude='*.class' \
  '(API[_-]?KEY|OPENAI_API_KEY|AWS_SECRET|AWS_ACCESS_KEY|SECRET_KEY|PRIVATE_KEY|Bearer [A-Za-z0-9._-]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})' \
  . 2>/dev/null || true)"

if [ -n "$MATCHES" ]; then
  echo -e "${RED}  possible secret patterns found (review before push):${NC}"
  echo "$MATCHES" | sed 's/^/    /'
else
  echo "  no API key / secret patterns found in project files"
fi

if [ "$SECRET_REMOVED" -gt 0 ]; then
  echo -e "${GREEN}✔ Removed $SECRET_REMOVED secret file(s)${NC}"
fi

# --- 3) Ensure .gitignore covers regeneratable / sensitive paths ---
echo -e "\n${CYAN}[3/4] Ensuring .gitignore for git push hygiene...${NC}"
cat > .gitignore << 'EOF'
# Build output
bin/
out/
target/
build/
*.class

# Secrets / local env
.env
.env.*
credentials.json
service-account.json
secrets.json

# OS / editor
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.idea/
*.iml
.vscode/
EOF
echo -e "${GREEN}✔ Wrote .gitignore${NC}"

# --- 4) Docker: stop containers and prune unused resources ---
echo -e "\n${CYAN}[4/4] Docker cleanup...${NC}"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo -e "${YELLOW}  Docker not usable in this environment — skipped.${NC}"
  echo "  Enable WSL integration in Docker Desktop if you need this step."
else
  # Stop all running containers
  RUNNING="$(docker ps -q 2>/dev/null || true)"
  if [ -n "$RUNNING" ]; then
    echo "  stopping running containers..."
    # shellcheck disable=SC2086
    docker stop $RUNNING >/dev/null || true
  else
    echo "  no running containers"
  fi

  # Remove stopped containers, unused networks, images, volumes, build cache
  echo "  pruning unused containers, networks, images, volumes, and build cache..."
  docker container prune -f >/dev/null 2>&1 || true
  docker network prune -f >/dev/null 2>&1 || true
  docker image prune -af >/dev/null 2>&1 || true
  docker volume prune -f >/dev/null 2>&1 || true
  docker builder prune -af >/dev/null 2>&1 || true
  echo -e "${GREEN}✔ Docker resources pruned${NC}"
fi

echo -e "\n${GREEN}=== Cleanup complete ===${NC}"
echo "Safe to git init / commit / push: keep src/ and start.sh (and this cleanup.sh)."
