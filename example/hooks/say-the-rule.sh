#!/usr/bin/env bash

# What a session is given at its start: the rule, with the ceiling the settings
# ask for written into it.
payload="$(cat)"

. "$(dirname "$0")/lib/say.sh"
. "$(dirname "$0")/lib/state.sh"

apply_migrations

session_id="$(hook_field "$payload" session_id)"
if [ -n "$session_id" ]; then plugin_mark "said/$session_id"; fi

said() {
  if setting_on GREETING; then
    printf 'Rules for this session%s.\n\n' \
      "$([ -n "$(setting_value GREETING_NAME)" ] && printf ', %s' "$(setting_value GREETING_NAME)")"
  fi
  sed "s/{ceiling}/$(setting_value LINE_CEILING)/" "$PLUGIN_ROOT/rules/house.md"
}

said | hook_say "$(hook_event_of "$payload")"
