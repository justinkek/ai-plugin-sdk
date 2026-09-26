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

# Whether a plugin has anything that would reach a session on this client. A
# plugin with only hooks reaches nothing on a client that runs none, and a
# client that runs neither hooks nor skills reaches nothing at all.
reaches() {
  local client="$1"
  if [ "$(client_runs "$client" .runs.hooks)" = "true" ] && plugin_has_hooks; then return 0; fi
  if [ "$(client_runs "$client" .runs.skills)" = "true" ]; then return 0; fi
  return 1
}

# A harness serves the clients it knows how to install for. A plugin is built
# for every one of them it can reach - naming `clients` in the manifest narrows
# that, and most plugins never need to.
served() {
  local client
  for client in $(jq --raw-output '.serves[]' "$sdk/harnesses/$1/harness.json"); do
    if [ "$(jq '.clients // empty | length' "$manifest")" != "" ]; then
      jq --exit-status --arg c "$client" '.clients | index($c)' "$manifest" >/dev/null || continue
    fi
    reaches "$client" || continue
    printf '%s\n' "$client"
  done
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
  local harness="$1" root="$2" family tools='{}'
  family="$(harness_says "$harness" .tools)"
  if [ -n "$family" ] && [ -f "$sdk/builder/tools/$family.json" ]; then tools="$(cat "$sdk/builder/tools/$family.json")"; fi
  # An event the harness runs a script of its own for is registered whether or
  # not the plugin has a hook there too, so the cloud refresh still runs for a
  # plugin with no session start hook of its own.
  #
  # A hook with an `on` list is registered in groups of its own. On a tool event
  # each kind becomes the client's tool names, and a pattern becomes Claude's
  # `if` where the client filters on the tool input; where it does not, the
  # hook reads its `on` list back through tool_entries. On any other event the
  # list is the event's own values.
  effective_hooks \
    | jq --tab --arg root "$root" --slurpfile harness "$sdk/harnesses/$harness/harness.json" \
      --argjson tools "$tools" --slurpfile events "$sdk/builder/events.json" \
      --argjson on "$(jq '.hook_on // {}' "$manifest")" '
    def command($script): {type: "command", command: ("bash \"" + $root + "/hooks/" + $script + "\"")};
    def parsed: capture("^(?<kind>[a-z_]+)(\\((?<pattern>.*)\\))?$") // {kind: ., pattern: null};
    def names($kind): ($tools.kinds[$kind].tools // [$kind]);
    ([$events[0].tool_events[] as $event | $events[0].events[$event]]) as $tool_events
    | def filtered($event; $script):
        ($on[$script] | map(parsed)) as $wants
        | if ($tool_events | index($event)) == null then
            [{matcher: ($wants | map(.kind) | join("|")), hooks: [command($script)]}]
          elif ($tools.filters_input // false) then
            [$wants[] as $want | names($want.kind)[] as $tool
              | {matcher: $tool, hooks: [command($script)
                  + (if $want.pattern != null and $tool == $tools.kinds[$want.kind].if
                     then {if: ($tool + "(" + $want.pattern + ")")} else {} end)]}]
            | unique
          else
            [{matcher: ("^(" + ([$wants[] | names(.kind)[]] | unique | join("|")) + ")$"),
              hooks: [command($script)]}]
          end;
    (($harness[0].own // {}) | map_values([])) + .
    | {hooks: (to_entries | map(.key as $event | {
      key: $event,
      value: (
        ((($harness[0].own[$event] // []) | map({type: "command", command: ("bash \"" + $root + "/" + . + "\"")}))
          + (.value | map(select($on[.] == null) | command(.)))) as $plain
        | [.value[] | select($on[.] != null)] as $scripts
        | ([$scripts[] as $script | filtered($event; $script)[]]) as $groups
        | (if ($plain | length) > 0 or ($groups | length) == 0 then [{hooks: $plain}] else [] end) + $groups)
    }) | from_entries)}
  '
}
