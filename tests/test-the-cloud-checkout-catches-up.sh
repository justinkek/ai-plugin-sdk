#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# The cloud container keeps a checkout of the plugin. A session start pulls it
# forward before anything reads it, so a container that has been up for days
# does not run last week's copy.
CLOUD="$BUILT/claude-code-cloud"
[ -d "$CLOUD" ] || { printf "  SKIP  this plugin has no cloud install\n"; exit 0; }

PAYLOAD='{"hook_event_name":"SessionStart","session_id":"test-refresh"}'

printf "Test group: a session start refreshes the checkout before it reads it\n"

commands() {
  jq --raw-output '.hooks.SessionStart[].hooks[].command' "$CLOUD/settings.json"
}

commands | head -1 | grep --quiet --fixed-strings 'refresh.sh'
assert "the refresh runs first at session start" "$?" \
  "whatever the snapshot held is what the session reads"

if jq --exit-status '(.hooks.SessionStart // []) | length > 0' "$MANIFEST" >/dev/null; then
  [ "$(commands | grep --count .)" -gt 1 ]
  assert "and the plugin's own hooks run after it" "$?" "a session would be handed nothing"
fi

printf "\nTest group: a checkout left behind catches up\n"

origin="$WORK/origin"
git init --quiet --bare --initial-branch=main "$origin"

work="$WORK/work"
git clone --quiet "$origin" "$work" 2>/dev/null
# The plugin as it is, with the folders this run built standing in for the
# committed ones, so the refresh pulls forward what these tests are about.
tar --create --file - --exclude .git --directory "$PLUGIN" . | tar --extract --file - --directory "$work"
rm -rf "$work/distributions"
cp -R "$BUILT" "$work/distributions"

published() {
  local version="$1" file
  for file in "$work/plugin.json" "$work/distributions/claude-code-cloud/plugin.json"; do
    jq --tab --arg v "$version" '.version = $v' "$file" > "$file.next" && mv "$file.next" "$file"
  done
  [ -f "$work/package.json" ] \
    && jq --tab --arg v "$version" '.version = $v' "$work/package.json" > "$work/package.next" \
    && mv "$work/package.next" "$work/package.json"
  git -C "$work" add --all
  git -C "$work" -c user.email=test -c user.name=test commit --quiet --message "version $version"
  git -C "$work" push --quiet origin HEAD:main 2>/dev/null
}

published 0.0.1

behind="$WORK/behind"
git clone --quiet --depth 1 "$origin" "$behind" 2>/dev/null

published 0.0.2

refreshed() {
  printf '%s' "$PAYLOAD" | env HOME="$WORK/cloud-home" \
    bash "$behind/distributions/claude-code-cloud/refresh.sh" 2>/dev/null
}

said="$(refreshed)"
status="$?"
[ "$status" = "0" ]
assert "the refresh exits 0" "$?" "exited $status, and a session start would fail"

grep --quiet --fixed-strings '"version": "0.0.2"' "$behind/plugin.json"
assert "the checkout moves to the published version" "$?" \
  "it stays where the snapshot left it, however old that is"

printf '%s' "$said" | grep --quiet --fixed-strings '0.0.2 replaces 0.0.1'
assert "and the session is told what changed" "$?" "it said '$said'"

[ -f "$WORK/cloud-home/.claude/settings.json" ]
assert "the new version installs itself" "$?" "the skills and registrations stay as they were"

printf "\nTest group: a refresh with nothing to pull changes nothing\n"

said="$(refreshed)"
[ -z "$said" ]
assert "a checkout already current says nothing" "$?" "it said '$said'"

git -C "$behind" remote set-url origin "$WORK/gone"
said="$(refreshed)"
status="$?"

[ "$status" = "0" ]
assert "an unreachable remote exits 0" "$?" "exited $status, and the session would not start"

grep --quiet --fixed-strings '"version": "0.0.2"' "$behind/plugin.json"
assert "and leaves the checkout it had" "$?" "the checkout was emptied by a failed refresh"

counted
