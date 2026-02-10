#!/usr/bin/env bash
# Bump the version in game/version.cfg.
# Usage: ./scripts/update_version.sh [major|minor|patch]
# Default: patch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PROJECT_DIR/game/version.cfg"

if [ ! -f "$VERSION_FILE" ]; then
  echo "Error: $VERSION_FILE not found" >&2
  exit 1
fi

BUMP="${1:-patch}"
VERSION=$(grep '^version=' "$VERSION_FILE" | head -1 | sed 's/version="//' | sed 's/"//')

IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *) echo "Usage: $0 [major|minor|patch]"; exit 1 ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

cat > "$VERSION_FILE" << EOF
[version]
version="$NEW_VERSION"
EOF

echo "Bumped version: $VERSION -> $NEW_VERSION"
