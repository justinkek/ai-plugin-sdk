#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

printf "Test group: shellcheck has nothing to say about the SDK's own shell\n"

if ! command -v shellcheck >/dev/null 2>&1; then
  printf "  SKIP  shellcheck is not installed here, so this checked nothing\n"
  printf "        install it and run again: the suite does not carry it\n\n"
  exit 0
fi

# The plugin's own scripts are the plugin's business. This holds the SDK.
files="$(git -C "$SDK" ls-files '*.sh' 'build' 'tests/run-tests' | grep --invert-match '^example/')"

# --external-sources so it follows a source line into the file it names, which
# is the only way it sees one function to a file as one library.
said="$(cd "$SDK" && shellcheck --severity=warning --external-sources $files 2>&1)"
outcome="$?"

[ "$outcome" = "0" ]
assert "every file is clean at warning and above" "$outcome" \
  "$(printf '%s' "$said" | head -20)"

printf "\nTest group: nothing is silenced without saying why\n"

# A disable with no reason above it is a warning someone waved through.
unexplained=""
found=0
while read -r hit; do
  [ -n "$hit" ] || continue
  found=$((found + 1))
  file="${hit%%:*}"
  line="${hit#*:}"
  line="${line%%:*}"
  before="$(sed -n "$((line - 1))p" "$SDK/$file")"
  before="${before#"${before%%[![:space:]]*}"}"
  case "$before" in
    '#'*) ;;
    *) unexplained="$unexplained $file:$line" ;;
  esac
# Anchored, so this line — which names the phrase rather than being one — is
# not a directive the check finds in itself.
done < <(cd "$SDK" && grep -rnE '^[[:space:]]*#+[[:space:]]*shellcheck[[:space:]]+disable' $files || true)

[ -z "$unexplained" ]
assert "every disable carries a reason on the line above" "$?" \
  "$unexplained is silenced and nothing says why"

# A pattern that matches nothing would pass this group without reading anything.
[ "$found" -gt 0 ]
assert "and there were disables to check" "$?" \
  "the pattern found none at all, so the group proved nothing"

counted
