#!/bin/bash
PROJECT_DIR="$(pwd)"
CLAUDE_DIR="$PROJECT_DIR/claude_ready"
BACKUP_DIR="$PROJECT_DIR/backup_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

echo "🔄 Starting merge of Claude fixes back into project..."

# Loop over all *_FULL.swift files in claude_ready/
find "$CLAUDE_DIR" -type f -name "*_FULL.swift" | while read -r claude_file; do
    # Original filename without _FULL
    base_name=$(basename "$claude_file")
    original_name="${base_name/_FULL/}"

    # Find original file path by searching project folder
    original_file=$(find "$PROJECT_DIR" -type f -name "$original_name" | head -n 1)

    if [[ -z "$original_file" ]]; then
        echo "⚠️ Original file for $original_name not found, skipping."
        continue
    fi

    echo "📂 Backing up $original_file to $BACKUP_DIR"
    cp "$original_file" "$BACKUP_DIR/"

    echo "📥 Overwriting $original_file with $claude_file"
    cp "$claude_file" "$original_file"
done

echo "✅ Merge complete. Backups saved in $BACKUP_DIR"
