#!/usr/bin/env bash

. "${BASH_SOURCE[0]%/*}/shell.sh"

# What a hook reads when it asks for a setting. Nothing here knows a plugin's
# name, its prefix or any of its keys: the build writes plugin-manifest.sh
# beside this file from the plugin's manifest, and this reads that.

# The libraries sit at <plugin>/hooks/lib, so the plugin's own directory is two
# above them wherever the install put it.
# One fork, not three: a hook may be run by a relative path, so the directory is
# resolved once, and the plugin's own is two components above it.
PLUGIN_LIB="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
PLUGIN_ROOT="${PLUGIN_LIB%/*/*}"
. "$PLUGIN_LIB/plugin-manifest.sh"

plugin_named_home="${PLUGIN_PREFIX}_HOME"
PLUGIN_HOME="${!plugin_named_home:-$HOME/.$PLUGIN_NAME}"
PLUGIN_SETTINGS="$PLUGIN_HOME/settings"
PLUGIN_STATE="$PLUGIN_HOME/state"

# A default is written in the manifest before there is a home to point at, so
# it names the two directories and they are filled in here.
plugin_expanded() {
  local value="$1"
  value="${value//\{state\}/$PLUGIN_STATE}"
  value="${value//\{home\}/$PLUGIN_HOME}"
  printf '%s' "$value"
}

settings_file_value() {
  local key="$1" value
  [ -f "$PLUGIN_SETTINGS" ] || return 1
  value="$(sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$PLUGIN_SETTINGS" \
    | sed 's/[[:space:]]*$//' | tail -n 1)"
  [ -n "$value" ] || return 1
  printf '%s' "$value"
}

# A value a setting cannot take is no setting at all: a count that is not a
# number counts nothing, a switch that is neither on nor off switches nothing.
# The default stands rather than the hook reading something it has no rule for.
plugin_setting_holds() {
  local key="$1" value="$2"
  case "$(plugin_setting_kind "$key")" in
    count) case "$value" in '' | *[!0-9]*) return 1 ;; esac ;;
    switch) case "$value" in on | off) ;; *) return 1 ;; esac ;;
    choice)
      printf '%s\n' $(plugin_setting_values "$key") | grep --quiet --line-regexp --fixed-strings "$value" \
        || return 1
      ;;
  esac
  return 0
}

# A setting is named without its prefix here, and carries it everywhere a
# person writes it: in the file, in the environment, and in the settings skill.
setting_value() {
  local key="$1" named="${PLUGIN_PREFIX}_$1" value default
  default="$(plugin_expanded "$(plugin_setting_default "$key")")"

  value="${!named-}"
  [ -n "$value" ] || value="$(settings_file_value "$named")"
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

setting_on() { [ "$(setting_value "$1")" = "on" ]; }

# A setting with no default is unset until someone sets it, and a hook that
# reads one asks whether it was set before it reads it.
setting_is_set() { [ -n "$(setting_value "$1")" ]; }

# Read off disk rather than built in, so a copy that replaces itself mid-session
# reports the version that is now there.
installed_version() {
  local line
  while read -r line; do
    case "$line" in
      *'"version"'*)
        line="${line#*\"version\"}"
        line="${line#*:}"
        line="${line#*\"}"
        printf '%s' "${line%%\"*}"
        return 0
        ;;
    esac
  done < "$PLUGIN_ROOT/plugin.json"
  return 1
}

# A plugin that has to move something an older version left behind ships
# hooks/migrations.sh. It runs once per version, before anything reads state.
apply_migrations() {
  local applied="" installed marker="$PLUGIN_STATE/applied-version"

  # The common case is a marker written after the manifest it was read from.
  # Nothing has changed, so nothing is read.
  [ -f "$marker" ] && [ "$marker" -nt "$PLUGIN_ROOT/plugin.json" ] && return 0

  [ -f "$marker" ] && read -r applied < "$marker"
  installed="$(installed_version)" || return 0
  [ "$applied" = "$installed" ] && return 0

  [ -f "$PLUGIN_LIB/migrations.sh" ] && . "$PLUGIN_LIB/migrations.sh"

  mkdir -p "$PLUGIN_STATE" 2>/dev/null || return 0
  printf '%s\n' "$installed" > "$marker" 2>/dev/null
  return 0
}

# A marker under the plugin's own state: one session that has been spoken to,
# one thing done once per install. The name is a path, so a marker per session
# goes under a directory named for what it records.
plugin_marked() { [ -f "$PLUGIN_STATE/$1" ]; }

plugin_mark() {
  mkdir -p "$(dirname "$PLUGIN_STATE/$1")" 2>/dev/null && : > "$PLUGIN_STATE/$1" 2>/dev/null
  return 0
}

# Leaves the mark, and says whether it was already there.
plugin_mark_once() {
  plugin_marked "$1" && return 0
  plugin_mark "$1"
  return 1
}
