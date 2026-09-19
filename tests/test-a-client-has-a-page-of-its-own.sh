#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A page is the plugin's where it has one, and the SDK's otherwise.
source_of() {
  local named="$1" client="$2" where
  for where in "$PLUGIN/clients/$client/$named" "$SDK/clients/$client/$named"; do
    if [ -s "$where" ]; then printf '%s' "$where"; return 0; fi
  done
  return 1
}

points_at() { sed -n "1s/^{same as \\([a-z-]*\\)}$/\\1/p" "$1"; }

served() {
  jq --raw-output --slurpfile plugin "$MANIFEST" \
    '.serves[] | select(. as $c | $plugin[0].clients | index($c))' "$SDK/harnesses/$1/harness.json"
}

printf "Test group: every client the plugin names is one some harness installs for\n"

while read -r client; do
  found=""
  for folder in "$SDK"/harnesses/*/; do
    jq --raw-output '.serves[]' "$folder/harness.json" | grep --quiet --line-regexp "$client" && found=1
  done
  [ -n "$found" ]
  assert "$client is a client something installs for" "$?" \
    "the manifest names it and no harness knows how, so nobody on it gets the plugin"
done < <(jq --raw-output '.clients[]' "$MANIFEST")

printf "\nTest group: a client a distribution serves is one it can tell apart\n"

for distribution in $(distributions); do
  count="$(served "$distribution" | wc -l)"
  while read -r client; do
    [ -n "$(jq --raw-output '.name' "$(source_of client.json "$client")" 2>/dev/null)" ]
    assert "$client says what it is called" "$?" \
      "the section for it in a skill would open with a blank heading"

    # One client needs no signature: a session in that folder is already it.
    [ "$count" = "1" ] || source_of signature.md "$client" >/dev/null
    assert "$distribution can recognise $client" "$?" \
      "the skills branch on a signature that is not written down"

    for named in install update uninstall reload settings; do
      source_of "$named.md" "$client" >/dev/null
      assert "and $named.md says what $client does" "$?" "the branch for it would be empty"
    done
  done < <(served "$distribution")
done

printf "\nTest group: a page a client shares says so, and no page is a copy\n"

for source in "$SDK"/clients/*/*.md "$PLUGIN"/clients/*/*.md; do
  [ -f "$source" ] || continue
  pointed="$(points_at "$source")"
  [ -n "$pointed" ] || continue
  named="$(basename "$source")"
  label="$(basename "$(dirname "$source")")/$named"

  target="$(source_of "$named" "$pointed")" && [ -z "$(points_at "$target")" ]
  assert "$label points at a page that is there" "$?" \
    "clients/$pointed/$named is missing, or points on again"
done

for named in install.md update.md uninstall.md reload.md settings.md signature.md; do
  copied=""
  for source in "$SDK"/clients/*/"$named"; do
    [ -f "$source" ] && [ -z "$(points_at "$source")" ] || continue
    for other in "$SDK"/clients/*/"$named"; do
      [ "$other" != "$source" ] && [ -f "$other" ] && [ -z "$(points_at "$other")" ] || continue
      cmp --silent "$source" "$other" && copied="$copied $(basename "$(dirname "$source")")"
    done
  done
  [ -z "$copied" ]
  assert "no $named is a copy of another" "$?" \
    "$copied hold the same page twice - one of them says {same as <client>}"
done

printf "\nTest group: a client's page carries that client and no other\n"

for distribution in $(distributions); do
  while read -r client; do
    page="$BUILT/$distribution/clients/$client.md"
    [ -s "$page" ]
    assert "$client has a page under $distribution" "$?" \
      "the install table links it and a reader lands nowhere"

    wrong=""
    for other in "$SDK"/clients/*/client.json; do
      named="$(basename "$(dirname "$other")")"
      [ "$named" = "$client" ] && continue
      grep --quiet --fixed-strings "$(jq --raw-output '.name' "$other")" "$page" && wrong="$wrong $named"
    done
    [ -z "$wrong" ]
    assert "and it names no other client" "$?" \
      "a reader who fetches it is handed$wrong as well, and may follow the wrong steps"
  done < <(served "$distribution")
done

counted
