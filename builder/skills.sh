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
# reporting a value that changes nothing.
settings_idle() {
  settings_json | jq --raw-output --arg prefix "$prefix" '
    [to_entries[] | select(.value.idle)] as $idle
    | if ($idle | length) == 0 then empty else
      ($idle[0]) as $first
      | "| Key                                        | Value |",
        "| ------------------------------------------ | ----- |",
        "| `\($prefix)_\($first.value.idle.key)` | `\($first.value.idle.value)` (set) |",
        "| `\($prefix)_\($first.key)` | "
          + (if ($first.value.default // "") != "" then "`\($first.value.default)` (set - n.a." else "set - n.a." end)
          + " because `\($prefix)_\($first.value.idle.key)` is set to `\($first.value.idle.value)`"
          + (if ($first.value.default // "") != "" then ") |" else " |" end),
        "",
        (if ($idle | length) == 1 then "One pair does this."
         elif ($idle | length) == 2 then "Two pairs do this."
         else "\($idle | length) pairs do this." end)
        + ($idle | map(" `\($prefix)_\(.value.idle.key) = \(.value.idle.value)` \(.value.idle.because), so `\($prefix)_\(.key)` \(.value.idle.so).") | join(""))
    end
  ' | pathed
}

# The settings skill is the one page written from the manifest rather than from
# a file, so the keys a plugin declares are the keys it names. Where a plugin
# has no pair that turns another off, that section of the skill goes.
settings_skill() {
  local out="$1/skills/settings/SKILL.md"
  [ -f "$out" ] || return 0
  python3 - "$out" "$(settings_table)" "$(settings_idle)" <<'FILL'
import pathlib, sys
out, table, idle = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = out.read_text().replace("{{settings-table}}", table)
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
