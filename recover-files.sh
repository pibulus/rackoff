#!/bin/bash

# RackOff File Recovery Script
# Recovers files from sandbox container to your real Documents/Archive

SANDBOX_ARCHIVE="$HOME/Library/Containers/com.pablo.rackoff/Data/Documents/Archive"
REAL_ARCHIVE="$HOME/Documents/Archive"

echo "🔍 RackOff File Recovery Tool"
echo "================================"
echo ""

# Check if sandbox archive exists
if [ ! -d "$SANDBOX_ARCHIVE" ]; then
    echo "❌ No sandbox archive found at: $SANDBOX_ARCHIVE"
    echo "Nothing to recover."
    exit 0
fi

# Count files in sandbox
FILE_COUNT=$(find "$SANDBOX_ARCHIVE" -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "✅ No files found in sandbox container."
    echo "Nothing to recover."
    exit 0
fi

echo "📦 Found $FILE_COUNT files in sandbox container:"
echo "$SANDBOX_ARCHIVE"
echo ""
echo "These will be moved to:"
echo "$REAL_ARCHIVE"
echo ""

# Ask for confirmation
read -p "Do you want to recover these files? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Recovery cancelled."
    exit 0
fi

echo ""
echo "🚀 Starting recovery..."
echo ""

# Create real archive if it doesn't exist
mkdir -p "$REAL_ARCHIVE"

# Counter for progress
MOVED=0
ERRORS=0

# Move all files from sandbox to real archive
for dir in "$SANDBOX_ARCHIVE"/*; do
    if [ -d "$dir" ]; then
        DIR_NAME=$(basename "$dir")
        TARGET_DIR="$REAL_ARCHIVE/$DIR_NAME"

        echo "📁 Processing folder: $DIR_NAME"

        # Create target directory if needed
        mkdir -p "$TARGET_DIR"

        # Move files from this directory
        for file in "$dir"/*; do
            if [ -f "$file" ]; then
                FILENAME=$(basename "$file")

                # Handle duplicates by adding number suffix
                TARGET_FILE="$TARGET_DIR/$FILENAME"
                if [ -f "$TARGET_FILE" ]; then
                    # File exists, add suffix
                    BASE="${FILENAME%.*}"
                    EXT="${FILENAME##*.}"
                    COUNTER=2

                    while [ -f "$TARGET_DIR/${BASE}_recovered_${COUNTER}.${EXT}" ] && [ $COUNTER -lt 100 ]; do
                        ((COUNTER++))
                    done

                    TARGET_FILE="$TARGET_DIR/${BASE}_recovered_${COUNTER}.${EXT}"
                fi

                # Move the file
                if mv "$file" "$TARGET_FILE" 2>/dev/null; then
                    echo "  ✅ Recovered: $FILENAME"
                    ((MOVED++))
                else
                    echo "  ❌ Failed: $FILENAME"
                    ((ERRORS++))
                fi
            fi
        done

        # Remove empty directory from sandbox
        rmdir "$dir" 2>/dev/null
    fi
done

echo ""
echo "================================"
echo "📊 Recovery Summary:"
echo "  ✅ Files recovered: $MOVED"
if [ $ERRORS -gt 0 ]; then
    echo "  ❌ Errors: $ERRORS"
fi
echo ""
echo "📍 Files are now in: $REAL_ARCHIVE"
echo ""

# Optional: Open the folder in Finder
read -p "Open Archive folder in Finder? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$REAL_ARCHIVE"
fi

echo "✨ Recovery complete!"