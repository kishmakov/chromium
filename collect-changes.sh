#!/bin/bash
set -euo pipefail

ROOT_DIR=$(pwd)
PATCH_FILE="$ROOT_DIR/combined_changes.patch"

rm -f "$PATCH_FILE" # Remove old patch if it exists

echo "Scanning for modified files in all nested Git repositories..."
echo "Root: $ROOT_DIR"

# Find all .git folders recursively
while IFS= read -r gitdir; do
    repo_dir=$(dirname "$gitdir")
    echo "-----------------------------------"
    echo "Repository: $repo_dir"
    echo "-----------------------------------"

    cd "$repo_dir"

    # Check for changes
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Changes detected in $repo_dir"

        # Append a header before each repo's patch
        echo -e "\n# ===== PATCH FROM: $repo_dir =====\n" >> "$PATCH_FILE"

        # Save staged + unstaged changes into patch
        git diff --ignore-submodules >> "$PATCH_FILE"
    else
        echo "No changes in $repo_dir"
    fi

    cd "$ROOT_DIR"
done < <(find "$ROOT_DIR" -type d -name ".git" -not -path "*/node_modules/*")

if [[ -f "$PATCH_FILE" ]]; then
    echo -e "\n✅ Combined patch created: $PATCH_FILE"
else
    echo -e "\n🎉 No changes found across sub-repositories."
fi
