#!/usr/bin/env bash

# build sources this file after builder/manifest.sh, so what that sets is
# already here. shellcheck reads one file at a time and cannot see it.
# shellcheck disable=SC2154

# Which harnesses this plugin is built for, and how each is told about a hook.

# In the order the harnesses declare, so every page lists them the same way.
harnesses() {
  for folder in "$sdk"/harnesses/*/; do
    printf '%s %s\n' "$(jq --raw-output '.order // 99' "$folder/harness.json")" "$(basename "$folder")"
  done | sort --numeric-sort | cut -d' ' -f2
}

harness_says() { jq --raw-output "$2 // empty" "$sdk/harnesses/$1/harness.json"; }

ships() {
  jq --exit-status --arg part "$2" '.ships | index($part)' \
    "$sdk/harnesses/$1/harness.json" >/dev/null
}

# A harness serves the clients it knows how to install for, and a plugin is
# built for the ones it names. Only the clients in both are written anywhere.
served() {
  jq --raw-output --slurpfile plugin "$manifest" \
    '.serves[] | select(. as $client | $plugin[0].clients | index($client))' \
    "$sdk/harnesses/$1/harness.json"
}

# A harness with no client this plugin names is a harness this plugin has no
# distribution for.
builds_for() { [ -n "$(served "$1")" ]; }

# An install serving one client is called what that client is called.
named_harness() {
  local named
  named="$(harness_says "$1" .name)"
  if [ -z "$named" ]; then named="$(named_client "$(served "$1" | head -1)")"; fi
  printf '%s' "$named"
}

# How a harness is told about a hook: every command runs the script through an
# interpreter, because a client that extracts without the executable bit runs
# nothing otherwise.
registration() {
  local harness="$1" root="$2"
  jq --tab --arg root "$root" --slurpfile harness "$sdk/harnesses/$harness/harness.json" '
    {hooks: (.hooks | to_entries | map({
      key: .key,
      value: [ { hooks:
        ((($harness[0].own[.key] // []) | map({type: "command", command: ("bash \"" + $root + "/" + . + "\"")}))
         + (.value | map({type: "command", command: ("bash \"" + $root + "/hooks/" + . + "\"")}))) } ]
    }) | from_entries)}
  ' "$manifest"
}
