#!/bin/bash
# Bump script version: major, minor, or patch
# feat — new feature
# fix — bug fix
# docs — documentation only
# style — formatting, whitespace, no functional changes
# refactor — code refactoring without functional changes
# perf — performance improvement
# test — adding or fixing tests
# chore — miscellaneous tasks, maintenance

set -e

MSG_COMMIT="feat: bump version to "
VERSION_FILE="VERSION"
README_FILE="README.md"


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

version=$(cat "$VERSION_FILE")
sed -i -E "s|(version-)[0-9]+\.[0-9]+\.[0-9]+(-blue.svg)|\1${version}\2|g" "$README_FILE"
echo "README.md updated to version $version"

# Git: create Release tag and push
git add .
git commit -am "$MSG_COMMIT $new_version"
git tag -s "v$new_version" -m "Release v$new_version"
git push origin v$new_version
git push