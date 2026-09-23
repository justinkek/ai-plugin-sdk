#!/usr/bin/env bash

# build sources this file after builder/manifest.sh, so what that sets is
# already here. shellcheck reads one file at a time and cannot see it.
# shellcheck disable=SC2154

# Where a plugin can be installed, and what runs when it is. Every fact here is
# the SDK's: it is true of the client, whatever plugin is built for it. A plugin
# writes none of this.

# What a client runs, against what this plugin has. A client that runs none of
# it is a client this plugin has nothing to reach a session with.
# `false // empty` is empty in jq, so a client that says it runs no hooks would
# read the same as one that says nothing. Ask whether the key is there.
client_runs() {
  jq --raw-output "if $2 == null then empty else $2 end" "$(client_source "$1")"
}

plugin_has_hooks() { [ "$(jq '[.hooks[]?[]] | length' "$manifest")" -gt 0 ]; }

# Supported when everything this plugin has reaches a session. Partial when some
# of it does.
supported_on() {
  local client="$1"
  if [ "$(client_runs "$client" .runs.hooks)" != "true" ] && plugin_has_hooks; then
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
  local harness client note shown=""
  for harness in $(harnesses); do
    builds_for "$harness" || continue
    for client in $(served "$harness"); do
      note="$(client_runs "$client" .note)"
      [ -n "$note" ] || continue
      case " $shown " in *" $client "*) continue ;; esac
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
