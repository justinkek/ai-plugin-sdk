#!/usr/bin/env bash

# Text on standard input, printed for the event named in $1.
hook_say() {
  local event="$1" said
  if hook_plain || [ -z "$event" ]; then cat; return 0; fi
  said="$(hook_escaped)"
  [ -n "$said" ] || return 0
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
    "$event" "$said"
}
