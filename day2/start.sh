#!/bin/bash
set -e

echo "[INFO] Compiling AstraKV..."
mkdir -p bin
shopt -s nullglob
sources=(src/*.java)
if [ ${#sources[@]} -eq 0 ]; then
    echo "[ERROR] No Java sources found in src/"
    exit 1
fi
javac -d bin "${sources[@]}"

echo "[INFO] Running Collision Test..."
java -cp bin CollisionTest

echo "[INFO] Verification Complete."