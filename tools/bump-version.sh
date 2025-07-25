#!/bin/bash
# Bump script version: major, minor, or patch

set -e

VERSION_FILE="VERSION"

if [ ! -f "$VERSION_FILE" ]; then
  echo "0.0.0" > "$VERSION_FILE"
fi

current_version=$(cat "$VERSION_FILE")

IFS='.' read -r major minor patch <<< "$current_version"

case "$1" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    echo "Usage: $0 [major|minor|patch]"
    exit 1
    ;;
esac

new_version="${major}.${minor}.${patch}"
echo "$new_version" > "$VERSION_FILE"

echo "✅ New version: $new_version"

# Git: create Release tag and push
git add .
git commit -am "chore: bump version to $new_version"
git tag -s "v$new_version" -m "Release v$new_version"
git push origin v$new_version