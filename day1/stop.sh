#!/usr/bin/env bash

# ANSI Color Codes
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}               Cleaning AstraKV Runtime Environment                   ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Remove compiled binaries
if [ -d "bin" ]; then
    echo "Removing compiled class files (bin/)..."
    rm -rf bin
fi

# Keep source code intact, but clean up temporary files if any exist
echo "Cleaning temporary metadata..."
find . -name "*.class" -type f -delete
find . -name "*~" -type f -delete

echo -e "${GREEN}✔ Environment clean completed successfully.${NC}"
echo -e "${BLUE}======================================================================${NC}"