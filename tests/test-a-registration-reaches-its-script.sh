#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

printf "Test group: every manifest the build writes is readable JSON\n"

for written in "$BUILT"/*/hooks/hooks.json "$BUILT"/*/settings.json \
  "$BUILT"/*/.claude-plugin/plugin.json "$BUILT"/*/.codex-plugin/plugin.json "$BUILT"/*/plugin.json; do
  [ -f "$written" ] || continue
  jq --exit-status . "$written" >/dev/null 2>&1
  assert "${written#$BUILT/} parses" "$?" "not readable as JSON"
done

printf "\nTest group: every command resolves inside the plugin, from wherever it is installed\n"

for distribution in $(distributions); do
  root="$(jq --raw-output '.root // empty' "$SDK/harnesses/$distribution/harness.json")"
  [ -n "$root" ] || continue
  root="${root//\{\{name\}\}/$NAME}"

  for registered in "$BUILT/$distribution/hooks/hooks.json" "$BUILT/$distribution/settings.json"; do
    [ -f "$registered" ] || continue
    while read -r command; do
      [ -n "$command" ] || continue
      inside="${command#"$root/"}"
      script="$(basename "$command")"

      [ "$inside" != "$command" ]
      assert "$distribution names $script from its own root" "$?" \
        "$command does not start with $root/"

      case "/$inside/" in
        */../*) false ;;
        *) true ;;
      esac
      assert "$distribution does not climb out of the plugin to reach it" "$?" \
        "$command escapes the plugin, and an installed copy has nothing above it"

      [ -f "$BUILT/$distribution/$inside" ]
      assert "$distribution ships $inside" "$?" \
        "no file there, so a copy of the plugin cannot run it"
    done < <(commands_of "$registered")
  done
done

printf "\nTest group: every hook the plugin registers is one it carries, and every hook it carries is registered\n"

for distribution in $(distributions); do
  registered="$(
    for where in "$BUILT/$distribution/hooks/hooks.json" "$BUILT/$distribution/settings.json"; do
      [ -f "$where" ] && commands_of "$where"
    done
    [ -f "$BUILT/$distribution/src/index.ts" ] \
      && grep --only-matching --extended-regexp '"[a-z-]+\.sh"' "$BUILT/$distribution/src/index.ts"
    true
  )"

  for script in "$BUILT/$distribution"/hooks/*.sh; do
    [ -f "$script" ] || continue
    named="$(basename "$script")"
    printf '%s' "$registered" | grep --quiet --fixed-strings "$named"
    assert "$distribution registers $named" "$?" "it ships and never fires"
  done
done

printf "\nTest group: what a hook sources is not left among the hooks\n"

# hooks/ is what a harness runs. A file the plugin's hooks source is not one of
# those, and leaving it there makes it look registered when nothing runs it.
for distribution in $(distributions); do
  left="$(ls "$BUILT/$distribution"/hooks/*-lib.sh "$BUILT/$distribution"/hooks/migrations.sh 2>/dev/null || true)"
  [ -z "$left" ]
  assert "$distribution leaves no helper in hooks/" "$?" "$left is there and nothing runs it"
done

for helper in "$PLUGIN"/hooks/*-lib.sh "$PLUGIN/hooks/migrations.sh"; do
  [ -f "$helper" ] || continue
  named="$(basename "$helper")"
  for distribution in $(distributions); do
    [ -d "$BUILT/$distribution/hooks/lib" ] || continue
    [ -f "$BUILT/$distribution/hooks/lib/$named" ]
    assert "$distribution carries $named beside the libraries" "$?" \
      "the plugin ships it and the build dropped it"
  done
done

printf "\nTest group: what a harness spawns itself is handed every hook the manifest declares\n"

for distribution in $(distributions); do
  [ -f "$BUILT/$distribution/src/index.ts" ] || continue
  while read -r script; do
    grep --quiet --fixed-strings "\"$script\"" "$BUILT/$distribution/src/index.ts"
    assert "the $distribution extension is handed $script" "$?" \
      "the manifest registers it and the extension never spawns it"
  done < <(jq --raw-output '.hooks[][]' "$MANIFEST")
done

counted
