#!/usr/bin/env bash
#
# Release helper: bumps semver git tag and optionally pushes it.
# Usage: ./scripts/release.sh [patch|minor|major|<version>] [--push]
#
set -euo pipefail

# Fetch remote tags if reachable so we don't collide with existing remote tags
git fetch --tags --quiet 2>/dev/null || true

# Find latest semver tag
LATEST_TAG=$(git tag -l "v[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | head -n 1)

if [[ -z "$LATEST_TAG" ]]; then
  echo "Error: No existing tag matching vX.Y.Z found." >&2
  exit 1
fi

VERSION="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

TYPE="patch"
PUSH=false
NEW_TAG=""

for arg in "$@"; do
  case "$arg" in
    patch|minor|major)
      TYPE="$arg"
      ;;
    --push|-p)
      PUSH=true
      ;;
    v[0-9]*.[0-9]*.[0-9]*|[0-9]*.[0-9]*.[0-9]*)
      if [[ "$arg" =~ ^v ]]; then
        NEW_TAG="$arg"
      else
        NEW_TAG="v$arg"
      fi
      TYPE="explicit"
      ;;
    --help|-h)
      echo "Usage: $0 [patch|minor|major|<version>] [--push]"
      echo ""
      echo "Examples:"
      echo "  $0               # bumps patch (e.g. v1.5.2 -> v1.5.3)"
      echo "  $0 minor         # bumps minor (e.g. v1.5.2 -> v1.6.0)"
      echo "  $0 major         # bumps major (e.g. v1.5.2 -> v2.0.0)"
      echo "  $0 --push        # bumps patch and immediately pushes tag to origin"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [patch|minor|major|<version>] [--push]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$NEW_TAG" ]]; then
  case "$TYPE" in
    major)
      NEW_TAG="v$((MAJOR + 1)).0.0"
      ;;
    minor)
      NEW_TAG="v${MAJOR}.$((MINOR + 1)).0"
      ;;
    patch)
      NEW_TAG="v${MAJOR}.${MINOR}.$((PATCH + 1))"
      ;;
  esac
fi

if git rev-parse -q --verify "refs/tags/$NEW_TAG" >/dev/null; then
  echo "Error: Tag $NEW_TAG already exists." >&2
  exit 1
fi

echo "Current version: $LATEST_TAG"
echo "New version:     $NEW_TAG ($TYPE)"

git tag "$NEW_TAG"
echo "Created tag $NEW_TAG"

if [[ "$PUSH" == true ]]; then
  git push origin "$NEW_TAG"
  echo "Pushed $NEW_TAG to origin"
elif [[ -t 0 ]]; then
  read -r -p "Push $NEW_TAG to origin now to trigger release? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git push origin "$NEW_TAG"
    echo "Pushed $NEW_TAG to origin"
  else
    echo "Tag created locally. Push later with: git push origin $NEW_TAG"
  fi
else
  echo "To trigger the release, run: git push origin $NEW_TAG"
fi
