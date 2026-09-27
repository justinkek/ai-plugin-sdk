#!/usr/bin/env bash

# build sources this file after builder/manifest.sh, so what that sets is
# already here. shellcheck reads one file at a time and cannot see it.
# shellcheck disable=SC2154

# Where a plugin can be installed, and what runs when it is. Every fact here is
# the SDK's: it is true of the client, whatever plugin is built for it. A plugin
# writes none of this.

# What a client runs, against what this plugin has. A client that runs none of
# it is a client this plugin has nothing to reach a session with.
# What a client runs is the SDK's knowledge, so it is read from the SDK's copy
# and never from a plugin's override. A plugin may rename a client; it may not
# claim the client runs something it does not.
#
# `false // empty` is empty in jq, so a client that says it runs no hooks would
# read the same as one that says nothing. Ask whether the key is there.
client_runs() {
  jq --raw-output "if $2 == null then empty else $2 end" "$sdk/clients/$1/client.json"
}

plugin_has_hooks() { [ "$(jq '[.hooks[]?[]] | length' "$manifest")" -gt 0 ]; }

# What this plugin's hooks need a client to run: each event it names, by its
# common name, and each tool kind a tool event's `on` list asks for. A kind
# asked for with no pattern is also listed as whole: the hook sees every call.
plugin_needs() {
  jq --raw-output --slurpfile events "$sdk/builder/events.json" '
    ($events[0].tool_events) as $tool_events
    | (.hooks // {}) | to_entries[] | select((.value | length) > 0)
    | "event \(.key)",
      (select(.key as $key | $tool_events | index($key))
        | .value[] | select(type == "object") | .on[]?
        | "kind \(sub("\\(.*$"; ""))", (select(test("\\(") | not) | "whole \(.)"))
  ' "$source_manifest" | sort --unique
}

# What this plugin needs that a client that runs hooks does not have, one to a
# line: an event it never fires, or a tool kind its hooks are never shown. A
# client can do one kind through another - Claude makes several replacements
# through its single Edit - and a plugin that asks for that other kind too, with
# no pattern, sees it there, so nothing is missed.
client_lacks() {
  local client="$1" needs need kind through
  [ "$(client_runs "$client" .runs.hooks)" = "true" ] || return 0
  needs="$(plugin_needs)"
  while read -r need; do
    case "$need" in
      '' | "whole "*) continue ;;
      "event "*)
        jq --exit-status --arg e "${need#event }" '.runs.events // [] | index($e)' \
          "$sdk/clients/$client/client.json" >/dev/null || printf '%s\n' "$need"
        ;;
      "kind "*)
        kind="${need#kind }"
        jq --exit-status --arg k "$kind" '.runs.tool_kinds // [] | index($k)' \
          "$sdk/clients/$client/client.json" >/dev/null && continue
        through="$(client_runs "$client" ".runs.done_through[\"$kind\"]")"
        if [ -n "$through" ] && printf '%s\n' "$needs" | grep --quiet --line-regexp --fixed-strings "whole $through"; then
          continue
        fi
        printf '%s\n' "$need${through:+ (done through $through here)}"
        ;;
    esac
  done <<< "$needs"
}

# Whether a client runs everything the SDK can give it. Nothing here asks about
# a plugin, so the SDK's own page and a plugin's page read the same rule.
client_supports_everything() {
  local client="$1"
  [ "$(client_runs "$client" .runs.hooks)" = "true" ] || return 1
  [ "$(client_runs "$client" .runs.skills)" = "true" ] || return 1
  [ "$(client_runs "$client" .runs.settings)" != "none" ] || return 1
  return 0
}

# Supported when everything this plugin has reaches a session. Partial when some
# of it does. A plugin with no hooks is not held to a client that runs none.
supported_on() {
  local client="$1"
  if [ "$(client_runs "$client" .runs.hooks)" != "true" ] && plugin_has_hooks; then
    printf 'Partial'
  elif [ -n "$(client_lacks "$client")" ]; then
    printf 'Partial'
  elif [ "$(client_runs "$client" .runs.skills)" != "true" ]; then
    printf 'Partial'
  elif [ "$(client_runs "$client" .runs.settings)" = "none" ]; then
    printf 'Partial'
  else
    printf 'Supported'
  fi
}

# Which distribution folder a reader installs that client from.
folder_for() {
  local client="$1" harness
  for harness in $(harnesses); do
    if served "$harness" | grep --quiet --line-regexp "$client"; then
      printf '%s' "$harness"
      return 0
    fi
  done
  return 1
}

compatibility_rows() {
  local vendor row client folder said
  while read -r vendor; do
    printf '## %s\n\n' "$vendor"
    printf '| Product | Surface | Where it runs | Install from | Support |\n'
    printf '| --- | --- | --- | --- | --- |\n'
    while read -r row; do
      client="$(printf '%s' "$row" | jq --raw-output '.client // empty')"
      if [ -z "$client" ]; then
        printf '| %s | %s | %s | | %s |\n' \
          "$(printf '%s' "$row" | jq --raw-output .product)" \
          "$(printf '%s' "$row" | jq --raw-output .surface)" \
          "$(printf '%s' "$row" | jq --raw-output .where)" \
          "$(printf '%s' "$row" | jq --raw-output '.says // "Not supported"')"
        continue
      fi
      folder="$(folder_for "$client")" || continue
      said="$(supported_on "$client")"
      printf '| %s | %s | %s | [distributions/%s](distributions/%s) | %s |\n' \
        "$(printf '%s' "$row" | jq --raw-output .product)" \
        "$(printf '%s' "$row" | jq --raw-output .surface)" \
        "$(printf '%s' "$row" | jq --raw-output .where)" \
        "$folder" "$folder" "$said"
    done < <(jq --compact-output --arg v "$vendor" \
      '.vendors[] | select(.vendor == $v) | .products[]' "$sdk/compatibility.json")
    printf '\n'
  done < <(jq --raw-output '.vendors[].vendor' "$sdk/compatibility.json")
}

# The caveats, one per client this plugin is built for that carries one.
compatibility_notes() {
  local harness client note lacks shown=""
  for harness in $(harnesses); do
    builds_for "$harness" || continue
    for client in $(served "$harness"); do
      case " $shown " in *" $client "*) continue ;; esac
      note="$(client_runs "$client" .note)"
      lacks="$(client_lacks "$client" | sed -e 's/^event //' -e 's/^kind //' | paste -sd ',' - | sed 's/,/, /g')"
      [ -n "$lacks" ] && note="${note:+$note }This plugin's hooks for $lacks never run here."
      [ -n "$note" ] || continue
      shown="$shown $client"
      printf '%s\n' "- **$(named_client "$client")** - $note"
    done
  done
}

compatibility_page() {
  local out="$1"
  {
    printf '# Where %s can be installed\n\n(audience: humans)\n\n' "$name"
    printf 'Supported means everything this plugin has reaches a session. Partial means\n'
    printf 'some of it does not, and the note under the tables says which. A row with no\n'
    printf 'link is a product nothing installs on yet.\n\n'
    compatibility_rows
    if [ -n "$(compatibility_notes)" ]; then
      printf '## What is missing where it says Partial\n\n'
      compatibility_notes
      printf '\n'
    fi
    printf '## Note\n\n%s\n' "$generated"
  } > "$out"
}
