#!/bin/bash

SIGNING_ENABLED=$(git config --global commit.gpgsign)
SIGNING_KEY=$(git config user.signingkey)

if [ "$SIGNING_ENABLED" != "true" ]; then
  echo "❌ Git commit signing is DISABLED"
  echo "👉 Enable it: git config --global commit.gpgsign true"
  exit 1
fi

if [ -z "$SIGNING_KEY" ]; then
  echo "❌ No signing key configured (user.signingkey is missing)"
  echo "👉 Set it: git config --global user.signingkey ~/.ssh/id_sign_git.pub"
  exit 1
fi

# Optional: Check if the private key exists (for SSH-style signing)
PRIVATE_KEY_PATH="${SIGNING_KEY%.*}"
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
  echo "❌ SSH private key not found at $PRIVATE_KEY_PATH"
  exit 1
fi

echo "✅ Git signing is correctly configured."
exit 0
