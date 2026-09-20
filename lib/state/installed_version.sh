#!/usr/bin/env bash

# Read off disk rather than built in, so a copy that replaces itself mid-session
# reports the version that is now there.
installed_version() {
  local line
  while read -r line; do
    case "$line" in
      *'"version"'*)
        line="${line#*\"version\"}"
        line="${line#*:}"
        line="${line#*\"}"
        printf '%s' "${line%%\"*}"
        return 0
        ;;
    esac
  done < "$PLUGIN_ROOT/plugin.json"
  return 1
}
