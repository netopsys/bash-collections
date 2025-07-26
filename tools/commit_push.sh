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

echo "Git log..."
git log --pretty=format:"%ad : %s" -n 5

if [[ -n $(git status --porcelain) ]]; then
  git status
  read -rp "👉 You want to commit change? (y/n): " CONFIRM

  if [[ "$CONFIRM" == "y" ]]; then
    git add .

    read -rp "👉 Write message commit : " MESSAGE
    git commit -am "$MESSAGE"

    read -rp "👉 You want to push? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
      git push
    fi

  fi

else

  git status
  git remote update > /dev/null 2>&1
  ahead=$(git rev-list --left-only --count origin/$(git rev-parse --abbrev-ref HEAD)...HEAD)
  echo "$ahead"

  if [ -n "$ahead" -gt 0 ]; then
    git status
    read -rp "👉 You want to push commits? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
      git push
    fi
    
  fi
fi

echo "Git log..."
git log --pretty=format:"%ad : %s" -n 5