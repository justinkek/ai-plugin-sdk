#!/usr/bin/env bash

# The items of a list setting that are on, one to a line. The plugin ships a
# list, and each layer turns an item on or off by name: the person's file, the
# project's, the project's local one, then the environment. The last layer to
# name an item decides it. `<key>_SHIPPED` set to off starts from nothing
# instead, so the list is only what the layers turn on.
#
# A layer names its items as a JSON object: `{"ctx": false, "resp": true}`.
# An item set to anything but false is on, so an item can carry settings of
# its own later without being read as off.
setting_list() {
  local key="$1" named="${PLUGIN_PREFIX}_$1" shipped="" environment files=() file
  [ "$(setting_value "${key}_SHIPPED")" = "off" ] || shipped="$(plugin_setting_default "$key")"

  # Without jq there is no layer to read, so the shipped list stands.
  if ! command -v jq >/dev/null 2>&1; then
    [ -z "$shipped" ] || printf '%s\n' "$shipped"
    return 0
  fi

  environment="${!named-}"
  if [ -n "$environment" ] \
    && ! printf '%s' "$environment" | jq --exit-status 'type == "object"' >/dev/null 2>&1; then
    printf '%s: %s is not a JSON object such as {"item": false}, so it was not read\n' \
      "$PLUGIN_NAME" "$named" >&2
    environment=""
  fi

  while IFS= read -r file; do files+=("$file"); done < <(settings_files)
  {
    for file in ${files[@]+"${files[@]}"}; do jq --compact-output --arg key "$key" '.[$key] // {}' "$file"; done
    [ -z "$environment" ] || printf '%s\n' "$environment"
  } | jq --raw-output --null-input --arg shipped "$shipped" '
    reduce (inputs | select(type == "object") | to_entries[]) as $item
      ($shipped | split("\n") | map(select(. != "")) | map({key: ., value: true}) | from_entries;
       .[$item.key] = ($item.value != false))
    | to_entries[] | select(.value) | .key
  '
}
