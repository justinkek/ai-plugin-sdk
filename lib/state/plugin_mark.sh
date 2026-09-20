#!/usr/bin/env bash

# Leaves a mark under the plugin's own state: one session that has been spoken
# to, one thing done once per install.
plugin_mark() {
  mkdir -p "$(dirname "$PLUGIN_STATE/$1")" 2>/dev/null && : > "$PLUGIN_STATE/$1" 2>/dev/null
  return 0
}
