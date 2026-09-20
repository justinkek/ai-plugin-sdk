#!/usr/bin/env bash

# The reply a turn ended with, counted against the ceiling.
payload="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "$0")/lib/reply.sh"
. "$(dirname "$0")/lib/notes.sh"

[ "$(hook_field "$payload" stop_hook_active)" = "true" ] && exit 0

session_id="$(hook_field "$payload" session_id)"
[ -n "$session_id" ] || exit 0

last="$(hook_last_reply "$payload" "$(hook_field "$payload" transcript_path)")"
[ -n "$last" ] || exit 0

ceiling="$(setting_value LINE_CEILING)"
ran="$(printf '%s\n' "$last" | grep --count '[[:alnum:]]' || true)"
[ "$ran" -gt "$ceiling" ] || exit 0

stop_note_record "$session_id" \
  "[house] The last reply ran $ran lines against a ceiling of $ceiling. Hold this one to it."
exit 0
