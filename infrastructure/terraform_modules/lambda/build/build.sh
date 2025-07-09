#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_ZIP="lambda.zip"

echo "Building gen_landing Lambda..."

# Remove previous build
rm -f "$OUTPUT_ZIP"

# Create a temporary directory for building
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy the handler and models to temp directory
cp "$SCRIPT_DIR/handler.py" "$TEMP_DIR/"
cp "$SCRIPT_DIR/models.py" "$TEMP_DIR/"
cp "$SCRIPT_DIR/landing_template.html" "$TEMP_DIR/"

# Install dependencies if requirements.txt exists
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    echo "Installing Python dependencies for ARM64 Lambda runtime..."
    
    # Install dependencies with ARM64 compatibility
    pip3 install -r "$SCRIPT_DIR/requirements.txt" \
        --target "$TEMP_DIR" \
        --platform linux_aarch64 \
        --implementation cp \
        --python-version 3.12 \
        --only-binary=:all: \
        --upgrade \
        --no-deps || {
        
        echo "ARM64 wheel installation failed, trying without platform constraints..."
        pip3 install -r "$SCRIPT_DIR/requirements.txt" \
            --target "$TEMP_DIR" \
            --upgrade
    }
fi

# Create the zip file
cd "$TEMP_DIR"
zip -r "$OUTPUT_ZIP" . -x "*.pyc" "__pycache__/*" "*.git*"

# Move the zip file to the build directory
mv "$OUTPUT_ZIP" "$SCRIPT_DIR/"

echo "Build completed successfully!"
echo "Lambda package: $SCRIPT_DIR/$OUTPUT_ZIP"
