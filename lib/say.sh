#!/usr/bin/env bash

# Clients differ in what they read from a hook. Every one of them reads this
# shape, and some read nothing else, so a hook that speaks says it this way.

. "${BASH_SOURCE[0]%/*}/payload.sh"
. "${BASH_SOURCE[0]%/*}/settings.sh"

# The event a hook was called for, out of the payload it was handed.
hook_event_of() { hook_field "$1" hook_event_name; }

# Text on standard input, as the inside of a JSON string.
hook_escaped() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r$//' -e 's/\t/\\t/g' \
    | awk 'BEGIN { ORS = "" } { if (NR > 1) printf "\\n"; printf "%s", $0 }'
}

# A harness reads the envelope or it reads the text. Setting <PREFIX>_PLAIN asks
# for the text, which is what a person piping a hook by hand wants, and what the
# build reads when it renders the reload skill.
hook_plain() {
  local named="${PLUGIN_PREFIX}_PLAIN"
  [ -n "${!named-}" ]
}

# Text on standard input, printed for the event named in $1.
hook_say() {
  local event="$1" said
  if hook_plain || [ -z "$event" ]; then cat; return 0; fi
  said="$(hook_escaped)"
  [ -n "$said" ] || return 0
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
    "$event" "$said"
}

# Text on standard input, printed for the event named in $1 and shown to the
# user as well. The context reaches the agent either way.
hook_say_aloud() {
  local event="$1" said
  if hook_plain || [ -z "$event" ]; then cat; return 0; fi
  said="$(hook_escaped)"
  [ -n "$said" ] || return 0
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
    "$said" "$event" "$said"
}
