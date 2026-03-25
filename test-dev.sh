#!/usr/bin/env bash
# Test vercel dev static file serving across three states for each project.
#
# Usage: ./test-dev.sh [project...]
#   With no arguments, tests all projects.
#   With arguments, tests only the named projects.
#
# States tested:
#   empty           - clean slate, no build outputs or staticfiles
#   after-build     - after pnpm vercel build
#   after-collectstatic - after manage.py collectstatic

set -euo pipefail

CLI=/Users/dnwpark/project/django-static/vercel/packages/cli
BASE=/Users/dnwpark/project/django-static/django-static-test

ALL_PROJECTS=(
  no-static-strategy
  standard-app-static
  standard-staticfiles-dirs
  manifest-app-static
  manifest-staticfiles-dirs
  whitenoise-with-static-root-app-static
  whitenoise-with-static-root-staticfiles-dirs
  whitenoise-empty-static-root-app-static
  whitenoise-empty-static-root-staticfiles-dirs
  whitenoise-manifest-with-static-root-app-static
  whitenoise-manifest-with-static-root-staticfiles-dirs
)

PROJECTS=("${@:-${ALL_PROJECTS[@]}}")

test_dev() {
  local project=$1
  local state=$2
  local port=""

  pkill -f "vc.js.*dev\|vc_init_dev" 2>/dev/null; sleep 2

  (cd "$CLI" && pnpm vercel dev --yes --cwd "$BASE/$project") >/tmp/vcdev_test.log 2>&1 &

  for i in $(seq 1 20); do
    sleep 1
    port=$(grep -o "localhost:[0-9]*" /tmp/vcdev_test.log 2>/dev/null | head -1 | cut -d: -f2)
    [ -n "$port" ] && break
  done

  if [ -z "$port" ]; then
    echo "$project [$state]: FAILED TO START"
    kill %1 2>/dev/null
    return
  fi

  sleep 3
  curl -s -o /dev/null "http://localhost:$port/" 2>/dev/null
  sleep 2

  CSS=$(curl -s "http://localhost:$port/" | grep -o 'href="[^"]*\.css[^"]*"' | head -1 | sed 's/href="//;s/"//')
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port$CSS")
  WARNING=$(grep -o "serving static files from STATIC_ROOT[^$]*" /tmp/vcdev_test.log 2>/dev/null | head -1)
  if [ -n "$WARNING" ]; then
    echo "$project [$state]: $CSS → $STATUS  ⚠ $WARNING"
  else
    echo "$project [$state]: $CSS → $STATUS"
  fi

  pkill -f "vc.js.*dev\|vc_init_dev" 2>/dev/null
}

for project in "${PROJECTS[@]}"; do
  echo ""
  echo "=== $project ==="

  # Clean
  rm -rf "$BASE/$project/.vercel/output" \
         "$BASE/$project/.vercel/python" \
         "$BASE/$project/staticfiles"

  # State 1: empty
  test_dev "$project" "empty"

  # State 2: after vercel build
  (cd "$CLI" && pnpm vercel build --yes --cwd "$BASE/$project") >/dev/null 2>&1
  test_dev "$project" "after-build"

  # State 3: after collectstatic
  (cd "$BASE/$project" && uv run python manage.py collectstatic --noinput) >/dev/null 2>&1 || true
  test_dev "$project" "after-collectstatic"

done

pkill -f "vc.js.*dev\|vc_init_dev" 2>/dev/null || true
echo ""
echo "Done."
