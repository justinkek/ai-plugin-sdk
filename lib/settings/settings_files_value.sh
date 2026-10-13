#!/usr/bin/env bash

# What the settings files say for one key, or nothing: the last file in
# settings_files that holds it. A file is JSON, so true and false are read as
# on and off, and a number as the number it is.
settings_files_value() {
  local key="$1" files=() file value
  command -v jq >/dev/null 2>&1 || return 1
  while IFS= read -r file; do files+=("$file"); done < <(settings_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  value="$(jq --raw-output --null-input --arg key "$key" '
    [inputs | .[$key] | select(. != null)] | last // empty
    | if type == "boolean" then (if . then "on" else "off" end)
      elif type == "string" then .
      else tojson end
  ' "${files[@]}")"
  [ -n "$value" ] || return 1
  printf '%s' "$value"
}
