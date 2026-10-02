#!/usr/bin/env bash
# Install the skills in this repo into ~/.claude/skills/, where Claude Code reads them.
# A copy, not a symlink: edit the skills here and re-run this to refresh the installed copy.
#
# Only `main` deploys. Pass --force to deploy another branch on purpose (with a warning).
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO/skills"
DEST="${HOME}/.claude/skills"
MARKER=".deployed-from-syncopenspec"

FORCE="${1:-}"
BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"

if [ "$BRANCH" != "main" ] && [ "$FORCE" != "--force" ]; then
  echo "deploy: refusing: on branch '$BRANCH', not 'main'." >&2
  echo "        Merge to main first, or re-run with --force to deploy this branch anyway." >&2
  exit 1
fi
if [ "$BRANCH" != "main" ]; then
  echo "deploy: WARNING: force-deploying branch '$BRANCH', not main." >&2
fi
if [ -n "$(git -C "$REPO" status --porcelain 2>/dev/null)" ]; then
  echo "deploy: WARNING: uncommitted changes; deploying the working tree, not a commit." >&2
fi

mkdir -p "$DEST"

for d in "$SRC"/*/; do
  name="$(basename "$d")"
  rm -rf "${DEST:?}/$name"
  cp -r "$d" "$DEST/$name"
  printf 'source: %s\n' "$SRC/$name" > "$DEST/$name/$MARKER"
  echo "deployed: $name -> $DEST/$name"
done

# A skill this repo deployed (it carries this repo's marker) whose source is gone was renamed
# or removed here: delete the stale installed copy. Skills from anywhere else are never touched.
for d in "$DEST"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  if [ -f "$d$MARKER" ] && [ ! -d "$SRC/$name" ]; then
    rm -rf "${DEST:?}/$name"
    echo "pruned: $name (marker present, source gone)"
  fi
done
