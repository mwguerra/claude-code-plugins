#!/bin/bash

# Script to clone filament repo, keep only .md files, and clean up empty directories

set -e  # Exit on any error

# Define the tmp folder path
TMP_DIR="$(pwd)/references"

# Remove the directory if it already exists
if [ -d "$TMP_DIR" ]; then
    echo "Removing existing directory: $TMP_DIR"
    rm -rf "$TMP_DIR"
fi

# Clone the repository
echo "Cloning https://github.com/filamentphp/filament to $TMP_DIR..."
git clone https://github.com/filamentphp/filament "$TMP_DIR"

# Change to the repo directory
cd "$TMP_DIR"

# SAFETY CHECK: Verify we are in the correct directory before any deletions
if [ "$(pwd)" != "$TMP_DIR" ]; then
    echo "ERROR: Failed to change to $TMP_DIR"
    echo "Current directory is: $(pwd)"
    echo "Exiting to prevent accidental file deletion."
    exit 1
fi

echo "Successfully changed to directory: $(pwd)"

# Delete all .github folders
echo "Removing all .github folders..."
find . -type d -name ".github" -exec rm -rf {} + 2>/dev/null || true

# Delete all files that do NOT end in .md (excluding .git directory)
echo "Deleting all non-.md files..."
find . -type f ! -name "*.md" ! -path "./.git/*" -delete

# Remove the .git directory as well
echo "Removing .git directory..."
rm -rf .git

# Rename root docs folder to general
if [ -d "docs" ]; then
    echo "Renaming root docs folder to general..."
    mv docs general
fi

# Move packages/package_name/docs to package_name
echo "Restructuring package docs folders..."
if [ -d "packages" ]; then
    for package_dir in packages/*/; do
        package_name=$(basename "$package_dir")
        if [ -d "packages/$package_name/docs" ]; then
            echo "  Moving packages/$package_name/docs to $package_name"
            mv "packages/$package_name/docs" "$package_name"
        fi
    done
fi

# Delete docs-assets folder
if [ -d "docs-assets" ]; then
    echo "Removing docs-assets folder..."
    rm -rf docs-assets
fi

# Delete packages folder (after docs have been moved out)
if [ -d "packages" ]; then
    echo "Removing packages folder..."
    rm -rf packages
fi

# Delete .md files in the root of tmp folder
echo "Removing .md files from root directory..."
find . -maxdepth 1 -type f -name "*.md" -delete

# Delete all empty directories
echo "Removing empty directories..."
find . -type d -empty -delete

echo ""
echo "Done! Only .md files remain in $TMP_DIR"
echo "Total .md files: $(find . -type f -name "*.md" | wc -l)"
