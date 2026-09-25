#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# COMPATIBILITY.md is the SDK's own page: which clients it supports, whatever
# plugin is built for them. It is generated, so the committed copy has to be
# what the generator writes.
printf "Test group: the committed page is the one the generator writes\n"

PAGE="$SDK/COMPATIBILITY.md"

[ -f "$PAGE" ]
assert "the page is committed" "$?" "a reader has nothing saying where a plugin can go"

"$SDK/compatibility-page" "$WORK/compatibility-again.md"
assert "the generator runs" "$?" "nothing can rewrite the page"

diff --unified "$PAGE" "$WORK/compatibility-again.md" > "$WORK/compatibility-drift"
assert "and writes what is committed" "$?" \
  "the page has drifted from compatibility.json: $(head -5 "$WORK/compatibility-drift")"

printf "\nTest group: every client the SDK has a folder for is on a row\n"

named() { jq --raw-output '.vendors[].products[].client // empty' "$SDK/compatibility.json"; }

for folder in "$SDK"/clients/*/; do
  client="$(basename "$folder")"
  named | grep --quiet --line-regexp --fixed-strings "$client"
  assert "$client is named by compatibility.json" "$?" \
    "the SDK has a folder for it and no product row reaches it"
done

printf "\nTest group: what the page explains is what the page marks Partial\n"

# The client names under the heading, one to a line.
explained() {
  sed -n '/What is missing where it says Partial/,$p' "$PAGE" \
    | sed -n 's/^- \*\*\(.*\)\*\* - .*/\1/p'
}

[ "$(explained | grep --count .)" -gt 0 ]
assert "the heading has something under it" "$?" "the group below would check nothing"

while read -r client; do
  [ -n "$client" ] || continue
  said="$(jq --raw-output '.name' "$SDK/clients/$client/client.json")"
  if grep --quiet --fixed-strings "$said" <(explained); then
    grep --quiet --fixed-strings "$(jq --raw-output '.note // "no note"' "$SDK/clients/$client/client.json")" "$PAGE"
    assert "$said is explained in the words its client.json uses" "$?" \
      "the page says something client.json does not"
  fi
done < <(named | sort --unique)

counted
