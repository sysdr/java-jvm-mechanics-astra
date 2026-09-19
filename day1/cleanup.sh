#!/usr/bin/env bash
# Cleanup runtime artifacts, secrets-ish local files, and unused Docker resources.
set -euo pipefail

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
RED=$'\033[0;31m'
NC=$'\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}               AstraKV Cleanup (Day 1)                                ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# ---------------------------------------------------------------------------
# Resolve docker CLI (native WSL or Windows Docker Desktop bridge)
# ---------------------------------------------------------------------------
resolve_docker() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        echo "docker"
        return 0
    fi
    if command -v docker.exe >/dev/null 2>&1 && docker.exe info >/dev/null 2>&1; then
        echo "docker.exe"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# 1) Stop local AstraKV / related Java processes
# ---------------------------------------------------------------------------
echo -e "\n${CYAN}[1/5] Stopping local AstraKV processes...${NC}"
if pgrep -f 'com\.astrakv\.(CLI|test\.AstraKVTest)' >/dev/null 2>&1; then
    pkill -f 'com\.astrakv\.(CLI|test\.AstraKVTest)' 2>/dev/null || true
    echo "  Stopped AstraKV Java processes."
else
    echo "  No AstraKV Java processes running."
fi
# If start.sh is mid-run in another shell, leave it; user can Ctrl-C there.

# ---------------------------------------------------------------------------
# 2) Remove build / temp artifacts not useful for git push
# ---------------------------------------------------------------------------
echo -e "\n${CYAN}[2/5] Removing build and temporary files...${NC}"
removed=0
if [ -d "bin" ]; then
    rm -rf bin
    echo "  Removed bin/"
    removed=1
fi
while IFS= read -r -d '' f; do
    rm -f "$f"
    echo "  Removed $f"
    removed=1
done < <(find . -type f \( -name '*.class' -o -name '*~' -o -name '*.log' -o -name '.DS_Store' \) -print0 2>/dev/null)

for d in .idea out target .classpath .project .settings; do
    if [ -e "$d" ]; then
        rm -rf "$d"
        echo "  Removed $d"
        removed=1
    fi
done
if [ "$removed" -eq 0 ]; then
    echo "  Nothing to remove."
fi

# ---------------------------------------------------------------------------
# 3) Scrub local secret / env files (never push these)
# ---------------------------------------------------------------------------
echo -e "\n${CYAN}[3/5] Checking for API keys and secret files...${NC}"
secret_hits=0
while IFS= read -r -d '' f; do
    case "$f" in
        ./.env.example) continue ;;
    esac
    rm -rf "$f"
    echo -e "  ${YELLOW}Removed secret-ish path: $f${NC}"
    secret_hits=1
done < <(find . -maxdepth 3 \( \
    -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.p12' \
    -o -name 'credentials.json' -o -name 'secrets' \) -print0 2>/dev/null)

# Soft scan sources for common key shapes (warn only; do not auto-edit code)
scan_out="$(grep -RInE \
    --exclude-dir=bin \
    --exclude-dir=.git \
    --exclude='cleanup.sh' \
    '(api[_-]?key\s*[:=]\s*["'\''][^"'\'']{8,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE KEY)' \
    . 2>/dev/null | grep -vE 'tokens\[|line\.split' || true)"
if [ -n "$scan_out" ]; then
    echo -e "  ${RED}Possible secret material found — review before git push:${NC}"
    echo "$scan_out"
    secret_hits=1
fi
if [ "$secret_hits" -eq 0 ]; then
    echo "  No API keys or secret files found."
fi

# Ensure .gitignore exists so bin/ and secrets stay out of commits
if [ ! -f .gitignore ]; then
    cat > .gitignore << 'EOF'
bin/
**/*.class
*.log
*~
.DS_Store
.idea/
*.iml
.vscode/
.env
.env.*
!.env.example
*.pem
*.p12
credentials.json
secrets/
EOF
    echo "  Wrote .gitignore"
fi

# ---------------------------------------------------------------------------
# 4) Stop Docker containers related to this project (if any)
# ---------------------------------------------------------------------------
echo -e "\n${CYAN}[4/5] Stopping Docker containers...${NC}"
DOCKER_CMD=""
if DOCKER_CMD="$(resolve_docker)"; then
    echo "  Using: $DOCKER_CMD"
    # Prefer project-labeled / named containers; fall back to compose in this dir
    if [ -f docker-compose.yml ] || [ -f compose.yml ] || [ -f compose.yaml ]; then
        $DOCKER_CMD compose down --remove-orphans 2>/dev/null \
            || $DOCKER_CMD-compose down --remove-orphans 2>/dev/null \
            || true
        echo "  Compose stack stopped (if present)."
    fi
    # Stop any containers matching astrakv / day1 naming (OR of two name filters)
    ids="$(
        { $DOCKER_CMD ps -aq --filter name=astrakv 2>/dev/null || true
          $DOCKER_CMD ps -aq --filter name=day1 2>/dev/null || true
        } | sort -u | tr '\n' ' '
    )"
    ids="$(echo "$ids" | xargs)"
    if [ -n "${ids:-}" ]; then
        # shellcheck disable=SC2086
        $DOCKER_CMD stop $ids >/dev/null 2>&1 || true
        # shellcheck disable=SC2086
        $DOCKER_CMD rm $ids >/dev/null 2>&1 || true
        echo "  Removed project-matched containers."
    else
        echo "  No project-matched containers."
    fi
else
    echo -e "  ${YELLOW}Docker daemon not available — skipped container stop.${NC}"
    echo "  Tip: start Docker Desktop and enable WSL integration, then re-run."
fi

# ---------------------------------------------------------------------------
# 5) Prune unused Docker resources (safe: unused only)
# ---------------------------------------------------------------------------
echo -e "\n${CYAN}[5/5] Pruning unused Docker resources...${NC}"
if [ -z "${DOCKER_CMD:-}" ]; then
    DOCKER_CMD="$(resolve_docker 2>/dev/null || true)"
fi
if [ -n "${DOCKER_CMD:-}" ] && $DOCKER_CMD info >/dev/null 2>&1; then
    $DOCKER_CMD container prune -f >/dev/null
    $DOCKER_CMD image prune -f >/dev/null
    $DOCKER_CMD network prune -f >/dev/null
    $DOCKER_CMD volume prune -f >/dev/null 2>/dev/null || true
    $DOCKER_CMD system prune -f >/dev/null
    echo "  Pruned stopped containers, dangling images, unused networks/volumes, and build cache."
else
    echo -e "  ${YELLOW}Docker daemon not available — skipped prune.${NC}"
fi

echo -e "\n${GREEN}✔ Cleanup completed successfully.${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Ready for git: keep start.sh, stop.sh, cleanup.sh, src/, .gitignore"
echo -e "Do not commit: bin/, *.class, .env, credentials, Docker volumes"
echo -e "${BLUE}======================================================================${NC}"
