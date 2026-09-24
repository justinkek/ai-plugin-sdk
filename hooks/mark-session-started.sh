#!/usr/bin/env bash

# A client that runs the session start hooks has been given whatever they
# print. This marks the session as spoken to, so the hook beside this one does
# not print it a second time on the first prompt.
payload="$(cat)"

. "$(dirname "$0")/lib/payload.sh"
. "$(dirname "$0")/lib/state.sh"

session_id="$(hook_field "$payload" session_id)"
[ -n "$session_id" ] || exit 0

plugin_mark "session-start/$session_id"
exit 0
