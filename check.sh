#!/usr/bin/env bash
# Usage inside a Job:  check <module>...   e.g.  check Solutions.Sol_foo
# Files are expected to have been placed under $WORKSPACE (ConfigMap, git clone, or initContainer).
set -euo pipefail
cd "${WORKSPACE:-/opt/prove2me_workspace}"
if [ "$#" -eq 0 ]; then set -- Solutions; fi
echo "== lean: $(lean --version)"
echo "== mathlib: $(git -C .lake/packages/mathlib rev-parse HEAD 2>/dev/null || cat .lake/packages/mathlib/.git-rev 2>/dev/null || echo pinned-at-build)"
echo "== building: $*"
start=$(date +%s)
lake build "$@"
echo "== OK in $(( $(date +%s) - start )) s"
