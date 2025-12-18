#!/bin/bash
# PHP file formatter hook
# Formats PHP files after they are created or edited

# Read hook input from stdin
INPUT=$(cat)

# Extract file path from the JSON input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# Check if we have a valid file path and it's a PHP file
if [ -z "$FILE_PATH" ] || [[ ! "$FILE_PATH" == *.php ]]; then
    exit 0
fi

# Check if the file exists
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Check if pint is available (Laravel Pint - PHP code style fixer)
if command -v pint &> /dev/null; then
    pint "$FILE_PATH" --quiet 2>/dev/null
    exit 0
fi

# Check if php-cs-fixer is available
if command -v php-cs-fixer &> /dev/null; then
    php-cs-fixer fix "$FILE_PATH" --quiet 2>/dev/null
    exit 0
fi

# If neither is available, just exit successfully
exit 0
