#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ZIP_NAME="lambda.zip"

rm -f "$ZIP_NAME"

# Install dependencies if a requirements file exists
if [ -f requirements.txt ]; then
  temp_dir="$(mktemp -d)"
  pip3 install -r requirements.txt -t "$temp_dir"
  (cd "$temp_dir" && zip -r9 "$SCRIPT_DIR/$ZIP_NAME" .)
  rm -rf "$temp_dir"
fi

# Always add the handler file
zip -g "$ZIP_NAME" handler.py > /dev/null

echo "Created $ZIP_NAME"
