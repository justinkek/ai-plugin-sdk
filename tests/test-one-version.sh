#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

printf "Test group: every manifest states the version the plugin declares\n"

for written in "$BUILT"/*/.claude-plugin/plugin.json "$BUILT"/*/.codex-plugin/plugin.json "$BUILT"/*/plugin.json; do
  [ -f "$written" ] || continue
  stated="$(jq --raw-output '.version' "$written")"
  [ "$stated" = "$VERSION" ]
  assert "${written#$BUILT/} states $VERSION" "$?" \
    "it states $stated, and an install caches by version, so the two disagree about what a reader is running"
done

printf "\nTest group: every skill was rendered from that version\n"

for skill in "$BUILT"/*/skills/reload/SKILL.md "$BUILT"/*/skills/update/SKILL.md \
  "$BUILT"/*/skills/uninstall/SKILL.md "$BUILT"/*/skills/settings/SKILL.md; do
  [ -f "$skill" ] || continue
  grep --quiet --fixed-strings "$NAME $VERSION" "$skill"
  assert "${skill#$BUILT/} names $VERSION" "$?" \
    "it names another version, and a session asked which one is installed would report that one"
done

printf "\nTest group: every manifest carries the same description\n"

said="$(jq --raw-output '.description // ""' "$MANIFEST")"
if [ -n "$said" ]; then
  for written in "$BUILT"/*/.claude-plugin/plugin.json "$BUILT"/*/.codex-plugin/plugin.json; do
    [ -f "$written" ] || continue
    stated="$(jq --raw-output '.description' "$written")"
    [ "$stated" = "$said" ]
    assert "${written#$BUILT/} says \"$said\"" "$?" "it says \"$stated\""
  done

  for written in "$BUILT"/*/.codex-plugin/plugin.json; do
    [ -f "$written" ] || continue
    stated="$(jq --raw-output '.interface.shortDescription' "$written")"
    [ "$stated" = "$said" ]
    assert "${written#$BUILT/} shows the same to a browsing user" "$?" "it shows \"$stated\""
  done
fi

printf "\nTest group: the version a hook reads is the version on disk\n"

for distribution in $(distributions); do
  [ -d "$BUILT/$distribution/hooks/lib" ] || continue
  read_back="$(bash -c ". \"$BUILT/$distribution/hooks/lib/settings.sh\" && installed_version")"
  [ "$read_back" = "$VERSION" ]
  assert "$distribution reads $VERSION off disk" "$?" \
    "it read '$read_back', so an update would be announced against the wrong version"
done

counted
