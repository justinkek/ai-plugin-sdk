#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# The SDK knows harnesses and clients. A plugin knows neither. If anything the
# SDK ships names a plugin, the next plugin inherits that plugin's wording.
printf "Test group: nothing the SDK ships names a plugin\n"

named="$(grep --recursive --line-number --ignore-case \
  --extended-regexp 'unsolicited.text|example.plugin' \
  "$SDK/build" "$SDK/lib" "$SDK/clients" "$SDK/skills" "$SDK/commands" "$SDK/harnesses" 2>/dev/null || true)"

[ -z "$named" ]
printf '%s' "$named" | sed 's/^/        /'
assert "no source under the SDK names one" "$?" \
  "a plugin that takes the SDK would inherit another plugin's name"

printf "\nTest group: nothing the SDK ships hard-codes a prefix\n"

# Every setting takes the plugin's own prefix, read out of the manifest.
prefixed="$(grep --recursive --line-number --extended-regexp '\b[A-Z]+_[A-Z_]*(HOME|CEILING|QUEUE|NOTE)' \
  "$SDK/lib" "$SDK/clients" "$SDK/skills" "$SDK/commands" 2>/dev/null \
  | grep --invert-match 'PLUGIN_\|{{prefix}}\|<PREFIX>' || true)"

[ -z "$prefixed" ]
printf '%s' "$prefixed" | sed 's/^/        /'
assert "every setting is named through the plugin's prefix" "$?" \
  "a key written out here is a key only one plugin has"

printf "\nTest group: a client page leaves the plugin's name open\n"

for source in "$SDK"/clients/*/*.md; do
  named="${source#$SDK/}"
  # A page that names an install by hand has nothing to fill in, and a plugin
  # with another name would be told to install this one.
  grep --quiet --extended-regexp 'plugin (install|add) [a-z]' "$source" \
    && wrong="$(grep --extended-regexp 'plugin (install|add) [a-z]' "$source" | grep --invert-match '{{name}}' || true)" \
    || wrong=""
  [ -z "$wrong" ]
  assert "$named installs {{name}} rather than a plugin it names" "$?" "$wrong"
done

counted
