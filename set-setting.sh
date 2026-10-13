#!/usr/bin/env bash

# Writes one setting into a settings file and leaves every other key in it as
# it was, in the order it was.
#
#   bash set-setting.sh [--project <directory> | --local <directory>] <key> <value>
#   bash set-setting.sh [--project <directory> | --local <directory>] <list key> <item> on|off
#
# With --project it writes the project's own .<plugin>/settings.json at that
# directory, which is committed with the project and read before the person's
# own file. With --local it writes .<plugin>/settings.local.json there, which
# is the person's own for that project, read before both, and never committed.
#
# The key is written the way the settings skill's table shows it, with or
# without the plugin's prefix, and goes into the file without it. A key this
# plugin does not have, a value the setting cannot take, or a file that is not
# JSON is refused, and nothing is written.

. "$(dirname "$0")/hooks/lib/settings.sh"

usage() {
  printf 'usage: set-setting.sh [--project <directory> | --local <directory>] <key> <value>\n' >&2
  printf '       set-setting.sh [--project <directory> | --local <directory>] <list key> <item> on|off\n' >&2
  exit 2
}

command -v jq >/dev/null 2>&1 || {
  printf 'set-setting.sh needs jq, and there is none here\n' >&2
  exit 1
}

settings_file="$PLUGIN_SETTINGS"
case "${1-}" in
  --project | --local)
    [ -d "${2-}" ] || {
      printf 'no project directory at %s\n' "${2-}" >&2
      exit 2
    }
    settings_file="$(cd "$2" && pwd)/.$PLUGIN_NAME/settings.json"
    [ "$1" = "--local" ] && settings_file="${settings_file%.json}.local.json"
    shift 2
    ;;
esac

bare="${1-}"
bare="${bare#"${PLUGIN_PREFIX}_"}"
named="${PLUGIN_PREFIX}_$bare"
kind="$(plugin_setting_kind "$bare")"

[ -n "$kind" ] || {
  printf '%s has no setting called %s.\n' "$PLUGIN_NAME" "$named" >&2
  exit 1
}

if [ "$kind" = "list" ]; then
  [ "$#" = "3" ] || usage
  item="$2"
  case "$3" in
    on) held=true ;;
    off) held=false ;;
    *)
      printf '%s takes an item and then on or off, not "%s".\n' "$named" "$3" >&2
      exit 1
      ;;
  esac
  change='.[$key] = ((.[$key] // {}) + {($item): ($held | fromjson)})'
  said="$named: $item $3"
else
  [ "$#" = "2" ] || usage
  item=""
  held="$2"
  plugin_setting_holds "$bare" "$held" || {
    printf '%s does not take "%s".\n' "$named" "$held" >&2
    case "$kind" in
      count) printf 'It takes a whole number.\n' >&2 ;;
      switch) printf 'It takes on or off.\n' >&2 ;;
      choice) printf 'It takes one of: %s\n' "$(plugin_setting_values "$bare")" >&2 ;;
    esac
    exit 1
  }
  change='.[$key] = $held'
  said="$named = $held"
fi

mkdir -p "$(dirname "$settings_file")" || {
  printf 'cannot write %s\n' "$settings_file" >&2
  exit 1
}

[ -f "$settings_file" ] || printf '{}\n' > "$settings_file"

jq --exit-status 'type == "object"' "$settings_file" >/dev/null 2>&1 || {
  printf '%s is not a JSON object, so nothing was written. Mend it or move it aside first.\n' \
    "$settings_file" >&2
  exit 1
}

jq --tab --arg key "$bare" --arg item "$item" --arg held "$held" "$change" "$settings_file" \
  > "$settings_file.new" && mv "$settings_file.new" "$settings_file"

printf '%s\n' "$said"
printf 'written to %s\n' "$settings_file"
