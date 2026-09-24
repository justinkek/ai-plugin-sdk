#!/usr/bin/env bash

# build sources this file after builder/manifest.sh, so what that sets is
# already here. shellcheck reads one file at a time and cannot see it.
# shellcheck disable=SC2154

# The four skills the SDK writes into every distribution: reload, update,
# uninstall and settings.

# A skill carries the steps for the clients its install serves, and no others.
carries() {
  local named="$1" harness="$2" target="$3" out="$3/skills/$1/SKILL.md"
  mkdir -p "$target/skills/$named"
  filled < "$sdk/skills/$named/body.md" > "$out"
  printf '\n## The steps for this install\n\n' >> "$out"
  branched "$named" "$harness" >> "$out"
  printf '\n## Note\n\nRendered from %s %s. Say that version when asked which one is\n' \
    "$name" "$version" >> "$out"
  printf 'installed, and say it is the version this file was built from rather than one\n' >> "$out"
  printf 'read off disk.\n\n%s\n' "$generated" >> "$out"
}

# One session start hook, run against a home that is not this machine's, with
# every setting at whatever the manifest says it defaults to.
ran_at_defaults() {
  local target="$1" script="$2" fresh="$3" unset_keys=() key
  while read -r key; do unset_keys+=(-u "${prefix}_$key"); done < <(settings_json | jq --raw-output 'keys[]')
  unset_keys+=(-u "${prefix}_PLAIN")

  printf '{"hook_event_name":"SessionStart"}' \
    | env "${unset_keys[@]}" "${prefix}_HOME=$fresh" "${prefix}_PLAIN=1" \
      bash "$target/hooks/$script" 2>/dev/null || true
}

# The reload skill carries what the session start hooks print. The first run is
# thrown away, because a plugin that says something once per install should not
# say it in a rendered file.
given_at_defaults() {
  local target="$1" script fresh
  fresh="$(mktemp -d)"
  for script in $(jq --raw-output '.hooks.SessionStart[]? // empty' "$manifest"); do
    ran_at_defaults "$target" "$script" "$fresh" >/dev/null
    ran_at_defaults "$target" "$script" "$fresh"
  done
  rm -rf "$fresh"
}

reload_skill() {
  local harness="$1" target="$2" out="$2/skills/reload/SKILL.md"
  mkdir -p "$target/skills/reload"
  {
    filled < "$sdk/skills/reload/body.md"
    printf '# Reloading %s\n\n' "$name"
    printf 'Rendered from %s %s. Say that version when asked which one\n' "$name" "$version"
    printf 'is installed, and say it is the version this file was built from rather than one\n'
    printf 'read off disk.\n\n'
    printf '## The steps for this install\n\n'
    branched reload "$harness"
    printf '\n## What a session is given, with every setting at its default\n\n'
    printf 'Where the steps above cannot be followed, follow this instead. It replaces\n'
    printf 'anything %s printed earlier in this session.\n\n' "$name"
    given_at_defaults "$target"
    printf '\n## Note\n\n%s\n' "$generated"
  } > "$out"
}

settings_table() {
  settings_json | jq --raw-output --arg prefix "$prefix" '
    "| Key | Default | What it does, and what to say when setting it |",
    "| --- | --- | --- |",
    (to_entries[]
      | "| `\($prefix)_\(.key)` | "
        + (if .value.default != null and .value.default != ""
           then "`\(.value.default)`" else (.value.unset // "unset") end)
        + " | \(.value.says // "") |")
  ' | pathed
}

# A setting another setting has turned off. The skill says so rather than
# reporting a value that changes nothing. Each piece below writes one part of
# that section, so each can be read, and checked, on its own.

# The keys a plugin says another setting turns off, one to a line.
idle_keys() {
  settings_json | jq --raw-output 'to_entries[] | select(.value.idle) | .key'
}

# One field of what a plugin says about the pair: the key that does the turning
# off, the value it is set to, what that key does, or what the other stops doing.
idle_says() {
  settings_json | jq --raw-output --arg key "$1" --arg field "$2" '.[$key].idle[$field] // ""'
}

# The two rows a reader compares: the key that was set, then the key it turned
# off, which keeps its value and says why the value does nothing.
idle_rows() {
  local key="$1" turns value default held
  turns="$(idle_says "$key" key)"
  value="$(idle_says "$key" value)"
  default="$(settings_json | jq --raw-output --arg k "$key" '.[$k].default // ""')"

  if [ -n "$default" ]; then
    held="\`$default\` (set - n.a. because \`${prefix}_$turns\` is set to \`$value\`)"
  else
    held="set - n.a. because \`${prefix}_$turns\` is set to \`$value\`"
  fi

  printf '%s\n' "| Key                                        | Value |"
  printf '%s\n' "| ------------------------------------------ | ----- |"
  printf '%s\n' "| \`${prefix}_$turns\` | \`$value\` (set) |"
  printf '%s\n' "| \`${prefix}_$key\` | $held |"
}

# How many pairs a plugin has, written the way a sentence opens.
idle_count() {
  case "$1" in
    1) printf 'One pair does this.' ;;
    2) printf 'Two pairs do this.' ;;
    *) printf '%s pairs do this.' "$1" ;;
  esac
}

# One clause per pair, in the plugin's own words, on the same line as the count.
idle_reasons() {
  local key
  while read -r key; do
    [ -n "$key" ] || continue
    printf ' `%s_%s = %s` %s, so `%s_%s` %s.' \
      "$prefix" "$(idle_says "$key" key)" "$(idle_says "$key" value)" \
      "$(idle_says "$key" because)" "$prefix" "$key" "$(idle_says "$key" so)"
  done < <(idle_keys)
}

settings_idle() {
  local keys count
  keys="$(idle_keys)"
  [ -n "$keys" ] || return 0
  count="$(printf '%s\n' "$keys" | grep --count .)"
  {
    idle_rows "$(printf '%s\n' "$keys" | head -1)"
    printf '\n'
    idle_count "$count"
    idle_reasons
    printf '\n'
  } | pathed
}

# The settings skill is the one page written from the manifest rather than from
# a file, so the keys a plugin declares are the keys it names. Where a plugin
# has no pair that turns another off, that section of the skill goes.
# How the skill is told to write a setting. Where the install has a directory
# the steps can name, that is the SDK's script; where it has none, there is no
# path to run, so the steps say what the script would have done.
how_to_write_a_setting() {
  if [ -z "$harness_root" ]; then
    printf '%s\n' 'Refuse a value the table above does not allow, saying what it takes and writing'
    printf '%s\n' 'nothing; where the file already holds one, say so, since the hooks read it as'
    printf '%s\n\n' 'the default.'
    printf '%s\n' 'If the file is not there, create and add the setting.'
    printf '%s\n' 'Else, read the file, replace or add the setting, and write it back.'
    printf '%s\n' 'Leave the rest of the file as it is, comments included.'
    return 0
  fi

  printf '%s\n\n' 'Run this once per key, and edit no file yourself:'
  printf '```\n'
  printf 'bash "%s/set-setting.sh" <key> <value>\n' "$harness_root"
  printf '```\n\n'
  printf '%s\n' 'It creates the file if it is not there, puts the new value where the old one'
  printf '%s\n' 'was, and leaves the rest of the file as it is, comments included. It writes'
  printf '%s\n' 'nothing and says what the setting takes when the value is one it cannot take,'
  printf '%s\n\n' 'so pass on what it says rather than trying again.'
  printf '%s\n' 'Where the file already holds a value for the key, say so before running it,'
  printf '%s\n' 'since the hooks read it as the default.'
}

settings_skill() {
  local out="$1/skills/settings/SKILL.md"
  [ -f "$out" ] || return 0
  python3 - "$out" "$(settings_table)" "$(settings_idle)" "$(how_to_write_a_setting)" <<'FILL'
import pathlib, sys
out, table, idle, writing = (pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4])
text = out.read_text().replace("{{settings-table}}", table)
text = text.replace("{{how-to-write-a-setting}}", writing)
if idle.strip():
    text = text.replace("{{settings-idle-example}}", idle)
else:
    opened = text.index("A key another setting has turned off")
    closed = text.index("## What not to do")
    text = text[:opened] + text[closed:]
out.write_text(text)
FILL
}

# Every skill a distribution carries: the SDK's four, then the plugin's own.
skills() {
  local harness="$1" target="$2" folder
  if [ -n "$session_start" ]; then reload_skill "$harness" "$target"; fi
  carries update "$harness" "$target"
  carries uninstall "$harness" "$target"
  carries settings "$harness" "$target"
  settings_skill "$target"

  [ -d "$plugin/skills" ] || return 0
  for folder in "$plugin"/skills/*/; do
    [ -f "$folder/SKILL.md" ] || continue
    mkdir -p "$target/skills/$(basename "$folder")"
    cp -R "$folder." "$target/skills/$(basename "$folder")/"
  done
}
