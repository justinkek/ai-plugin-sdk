#!/usr/bin/env bash

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
