#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A page written for a human and a page written for an agent read differently,
# and a reader who cannot tell which they have follows the wrong one.
printf "Test group: every page the build writes opens by saying who it is for\n"

for written in "$BUILT"/*/README.md "$BUILT"/*/clients/*.md "$INSTALL"; do
  [ -f "$written" ] || continue
  head -5 "$written" | grep --quiet --fixed-strings '(audience: '
  assert "${written#$OUT/} says who it is for" "$?" \
    "a reader cannot tell whether the steps are theirs to follow"
done

printf "\nTest group: a paragraph the other reader acts on carries the mark\n"

# The mark lasts one paragraph, so it opens one and does not hang loose.
for source in "$SDK"/clients/*/*.md "$SDK"/skills/*/body.md; do
  [ -f "$source" ] || continue
  loose="$(grep --line-number --fixed-strings '(audience: ' "$source" \
    | grep --invert-match --extended-regexp ':\(audience: (humans|agents)\)' || true)"
  [ -z "$loose" ]
  assert "${source#$SDK/} opens its marked paragraphs with the mark" "$?" "$loose"
done

printf "\nTest group: a mark names one of the two readers\n"

wrong="$(grep --recursive --only-matching '(audience: [a-z]*)' "$SDK/clients" "$SDK/skills" \
  | grep --invert-match --extended-regexp '\(audience: (humans|agents)\)' || true)"
[ -z "$wrong" ]
assert "every mark says humans or agents" "$?" "$wrong"

counted
