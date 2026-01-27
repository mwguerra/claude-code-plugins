#!/bin/bash
# Error Memory Plugin - Cross-Platform Hashing
# Dependencies: platform.sh (source it before this file)

# Guard against double-sourcing
[[ -n "$_ERROR_MEMORY_HASH_SH" ]] && return
_ERROR_MEMORY_HASH_SH=1

# Cross-platform SHA256 hash
# Usage: sha256 "string to hash"
sha256() {
    local input="$1"
    if command -v sha256sum &>/dev/null; then
        echo -n "$input" | sha256sum | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        echo -n "$input" | shasum -a 256 | cut -d' ' -f1
    else
        # Fallback to openssl
        echo -n "$input" | openssl dgst -sha256 | cut -d' ' -f2
    fi
}

# Hash a file
# Usage: sha256_file "/path/to/file"
sha256_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo ""
        return 1
    fi

    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        openssl dgst -sha256 "$file" | cut -d' ' -f2
    fi
}

# Create a short hash (first 12 chars) for display
# Usage: short_hash "full_hash_string"
short_hash() {
    local hash="$1"
    echo "${hash:0:12}"
}

export -f sha256 sha256_file short_hash
