#!/bin/bash

# feat: new feature
# fix: bug fix
# docs: documentation only
# style: formatting, whitespace, no functional changes
# refactor: code refactoring without functional changes
# perf: performance improvement
# test: adding or fixing tests
# chore: miscellaneous tasks, maintenance

set -e

echo "git log..."
git log --pretty=format:"%h | %ad | %an | %ae | %s %d" --date=iso -n 5

if [[ -n $(git status --porcelain) ]]; then
  git status
  read -rp "👉 You want to add change? (y/n): " CONFIRM

  if [[ "$CONFIRM" == "y" ]]; then
    git add .

    read -rp "👉 You want to commit change? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then

      read -rp "👉 Write message commit : " MESSAGE
      git commit -am "$MESSAGE"

      read -rp "👉 You want to push? (y/n): " CONFIRM
      if [[ "$CONFIRM" == "y" ]]; then
        git push
      fi

    fi
  fi

else

  echo "git status..."
  git status
  has_branch_is_ahead=$(git status | grep "Your branch is ahead of")

  if [[ -n "$has_branch_is_ahead" ]]; then
    read -rp "👉 You want to push commits? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
      git push
    fi
    
  fi
fi

echo "git log..."
git log --pretty=format:"%h | %ad | %an | %ae | %s %d" --date=iso -n 5
