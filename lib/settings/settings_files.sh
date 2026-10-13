#!/usr/bin/env bash

# The settings files a hook reads, one to a line, the one that loses first: the
# person's own, then the project's, then the project's local one, which is the
# person's own again but for one project and never committed. A file that is
# not a JSON object is left out and named, rather than read as saying nothing.
settings_files() {
  local directory file
  directory="$(project_settings_directory)" || directory=""
  for file in "$PLUGIN_SETTINGS" ${directory:+"$directory/settings.json" "$directory/settings.local.json"}; do
    [ -f "$file" ] || continue
    if jq --exit-status 'type == "object"' "$file" >/dev/null 2>&1; then
      printf '%s\n' "$file"
    else
      printf '%s: %s is not a JSON object, so none of it was read\n' "$PLUGIN_NAME" "$file" >&2
    fi
  done
}
