#!/usr/bin/env bash
# Usage inside a Job:  check <module>...   e.g.  check Solutions.Sol_foo
# Files are expected to have been placed under $WORKSPACE (ConfigMap, git clone, or initContainer).
set -euo pipefail
cd "${WORKSPACE:-/opt/prove2me_workspace}"
if [ "$#" -eq 0 ]; then set -- Solutions; fi
echo "== lean: $(lean --version)"
echo "== mathlib: $(git -C .lake/packages/mathlib rev-parse HEAD 2>/dev/null || echo unknown)"
echo "== building: $*"

# Sample the container's cgroup memory every 0.5 s and keep the peaks of
#   anon  = Lean's own heap, the figure that can trigger an OOM kill
#   file  = memory-mapped Mathlib .olean pages, reclaimable by the kernel
# so Job requests can be sized to what a proof really needs.
STAT=""
for f in /sys/fs/cgroup/memory.stat /sys/fs/cgroup/memory/memory.stat; do [ -r "$f" ] && STAT=$f && break; done
PEAKS=$(mktemp)
if [ -n "$STAT" ]; then
  ( a=0; m=0; while :; do
      ca=$(awk '$1=="anon"||$1=="rss"{print $2; exit}' "$STAT" 2>/dev/null || echo 0)
      cf=$(awk '$1=="file"||$1=="cache"{print $2; exit}' "$STAT" 2>/dev/null || echo 0)
      [ "${ca:-0}" -gt "$a" ] && a=$ca; [ "${cf:-0}" -gt "$m" ] && m=$cf
      echo "$a $m" > "$PEAKS"; sleep 0.5; done ) & SAMPLER=$!
fi

start=$(date +%s)
status=0
lake build "$@" || status=$?
echo "== lake exit $status after $(( $(date +%s) - start )) s"

if [ -n "${SAMPLER:-}" ]; then
  kill "$SAMPLER" 2>/dev/null || true
  read -r pa pf < "$PEAKS" || true
  echo "== peak memory: heap $(( ${pa:-0} / 1048576 )) MiB, mapped files $(( ${pf:-0} / 1048576 )) MiB"
fi
for f in /sys/fs/cgroup/memory.peak /sys/fs/cgroup/memory/memory.max_usage_in_bytes; do
  [ -r "$f" ] && echo "== cgroup peak total: $(( $(cat "$f") / 1048576 )) MiB" && break
done
exit $status
