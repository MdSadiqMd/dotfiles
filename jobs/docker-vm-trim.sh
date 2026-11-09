#!/usr/bin/env bash
# Docker VMM (UseLibkrun in Docker Desktop's settings-store.json) hands memory the
# Linux VM frees back to macOS, but Linux keeps spare RAM as file cache, so with a
# high limit the VM still grows toward it. Dropping the guest cache every 10 minutes
# lets that memory go back (measured 8.4 -> 5.7 GB). Skips while Docker is stopped.
set -u
docker=/usr/local/bin/docker
while true; do
  if "$docker" info >/dev/null 2>&1; then
    "$docker" run --rm --privileged --network none alpine:3.22 \
      sh -c 'sync && echo 3 >/proc/sys/vm/drop_caches' >/dev/null 2>&1 ||
      echo "$(date '+%F %T') drop_caches failed"
  fi
  sleep 600
done
