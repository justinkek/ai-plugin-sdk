#!/usr/bin/env bash

# Turns the person's settings file from the `KEY = value` lines the SDK wrote
# before 0.8.0 into settings.json, once, and keeps the old file beside it as
# settings.old. A plugin calls it from its own migrations.sh; nothing calls it
# otherwise.
#
# A list setting written the old way replaced the shipped list, so it comes
# across as its items turned on with `<key>_SHIPPED` off. A key this plugin no
# longer declares comes across as it was, for the plugin's own migration to
# move. A project's file is committed with the project, so it is left to the
# person to convert with the settings skill.
settings_converted() {
  local old="$PLUGIN_HOME/settings" line key value converted="{}" kind
  [ -f "$old" ] && [ ! -f "$PLUGIN_SETTINGS" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    key="$(printf '%s' "${line%%=*}" | tr -d '[:space:]')"
    value="$(printf '%s' "${line#*=}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$key" ] && [ "$key" != "$line" ] || continue
    key="${key#"${PLUGIN_PREFIX}_"}"
    kind="$(plugin_setting_kind "$key")"
    if [ "$kind" = "list" ]; then
      converted="$(printf '%s' "$converted" | jq --arg key "$key" --arg value "$value" '
        .[$key] = ($value | split(" ") | map(select(. != "")) | map({key: ., value: true}) | from_entries)
        | .[$key + "_SHIPPED"] = "off"')"
    else
      converted="$(printf '%s' "$converted" | jq --arg key "$key" --arg value "$value" '.[$key] = $value')"
    fi
  done < "$old"

  printf '%s\n' "$converted" > "$PLUGIN_SETTINGS" && mv "$old" "$PLUGIN_HOME/settings.old"
}
