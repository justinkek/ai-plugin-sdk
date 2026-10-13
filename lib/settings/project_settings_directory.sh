#!/usr/bin/env bash

# The nearest .<plugin> directory at or above the project that holds a settings
# file, so a hook run in a subdirectory reads what the project root holds. The
# home directory is where the person's own file sits, so the search stops short
# of it: that file is never read as a project's.
project_settings_directory() {
  local directory="$PLUGIN_PROJECT"
  while [ -n "$directory" ] && [ "$directory" != "$HOME" ]; do
    if [ -f "$directory/.$PLUGIN_NAME/settings.json" ] \
      || [ -f "$directory/.$PLUGIN_NAME/settings.local.json" ]; then
      printf '%s' "$directory/.$PLUGIN_NAME"
      return 0
    fi
    [ "$directory" = "/" ] && break
    directory="$(dirname "$directory")"
  done
  return 1
}
