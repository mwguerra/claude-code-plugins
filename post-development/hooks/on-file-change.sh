#!/bin/bash
# Post-development hook: on-file-change
# Triggered when files are written or edited
# Can be used to track changes during post-dev workflow

# Read input from stdin
INPUT=$(cat)

# Extract file path if available
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Check if this is a post-development file
if [[ "$FILE_PATH" == *".post-development"* ]]; then
  # Log the change (optional)
  echo "Post-development file updated: $FILE_PATH" >> /tmp/post-dev-changes.log 2>/dev/null || true
fi

# Exit successfully (don't block)
exit 0
