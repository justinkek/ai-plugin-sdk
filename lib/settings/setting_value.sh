#!/usr/bin/env bash

# A setting is named without its prefix here, and carries it everywhere a
# person writes it in the environment and in the settings skill. A settings
# file names it without the prefix, since the file is the plugin's own.
#
# The environment wins, then the files settings_files names, the last of them
# first, then the default. A project's file is committed with it, so everyone
# working in the project is held to the same values; the environment is how
# one person steps outside them for a while.
#
# A list setting is read as its items, space separated. setting_list hands them
# one to a line.
setting_value() {
  local key="$1" named="${PLUGIN_PREFIX}_$1" value default

  if [ "$(plugin_setting_kind "$key")" = "list" ]; then
    setting_list "$key" | paste -s -d ' ' -
    return 0
  fi

  default="$(plugin_expanded "$(plugin_setting_default "$key")")"
  value="${!named-}"
  [ -n "$value" ] || value="$(settings_files_value "$key")"
  [ -n "$value" ] || { printf '%s' "$default"; return 0; }

  if [ "$(plugin_setting_kind "$key")" = "switch" ]; then
    value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  fi

  if plugin_setting_holds "$key" "$value"; then
    plugin_expanded "$value"
  else
    printf '%s' "$default"
  fi
}
