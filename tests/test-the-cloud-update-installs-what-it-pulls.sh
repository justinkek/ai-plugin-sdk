#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# Pulling the checkout forward is not enough: what the new version added has to
# be copied into the home a session reads, or it waits for the next container.
CLOUD="$BUILT/claude-code-cloud"
[ -d "$CLOUD" ] || { printf "  SKIP  this plugin has no cloud install\n"; exit 0; }

UPDATE="$CLOUD/skills/update/SKILL.md"

printf "Test group: the update steps name a script that installs what it pulls\n"

named="$(grep --only-matching --extended-regexp '[a-z-]+\.sh' "$UPDATE" | sort --unique)"

printf '%s' "$named" | grep --quiet --line-regexp --fixed-strings refresh.sh
assert "the cloud update steps name refresh.sh" "$?" \
  "they name $(printf '%s' "$named" | tr '\n' ' '), none of which installs what it pulls"

for script in $named; do
  [ -x "$CLOUD/$script" ] || [ -x "$CLOUD/hooks/$script" ]
  assert "and $script is a script the build wrote" "$?" "there is nothing to run"
done

grep --quiet --fixed-strings install.sh "$CLOUD/refresh.sh"
assert "the script it names runs the install" "$?" \
  "an update pulls the checkout and copies none of it, so a new skill waits for the next session"

printf "\nTest group: an update in a session hands it what the new version added\n"

origin="$WORK/update-origin"
git init --quiet --bare --initial-branch=main "$origin"

work="$WORK/update-work"
git clone --quiet "$origin" "$work" 2>/dev/null
tar --create --file - --exclude .git --directory "$PLUGIN" . | tar --extract --file - --directory "$work"
rm -rf "$work/distributions"
cp -R "$BUILT" "$work/distributions"

published() {
  local version="$1" file
  for file in "$work/plugin.json" "$work/distributions/claude-code-cloud/plugin.json"; do
    jq --tab --arg v "$version" '.version = $v' "$file" > "$file.next" && mv "$file.next" "$file"
  done
  git -C "$work" add --all
  git -C "$work" -c user.email=test -c user.name=test commit --quiet --message "version $version"
  git -C "$work" push --quiet origin HEAD:main 2>/dev/null
}

published 0.0.1

running="$WORK/update-running"
git clone --quiet --depth 1 "$origin" "$running" 2>/dev/null

home="$WORK/update-home"
env HOME="$home" bash "$running/distributions/claude-code-cloud/install.sh" >/dev/null

mkdir -p "$work/distributions/claude-code-cloud/skills/newcomer"
printf -- '---\nname: newcomer\ndescription: added by the new version\n---\n' \
  > "$work/distributions/claude-code-cloud/skills/newcomer/SKILL.md"
printf -- '---\ndescription: added by the new version\n---\n\nInvoke it.\n' \
  > "$work/distributions/claude-code-cloud/commands/newcomer.md"
published 0.0.2

said="$(printf '{}' | env HOME="$home" bash "$running/distributions/claude-code-cloud/refresh.sh" 2>/dev/null)"
status="$?"

[ "$status" = "0" ]
assert "the update exits 0" "$?" "exited $status"

printf '%s' "$said" | grep --quiet --fixed-strings '0.0.2 replaces 0.0.1'
assert "it says which version replaces which" "$?" "it said '$said'"

[ -f "$home/.claude/skills/newcomer/SKILL.md" ]
assert "a skill the new version added is in place" "$?" \
  "it waits for the next session, and the update said it was done"

[ -f "$home/.claude/commands/$NAME-newcomer.md" ]
assert "so is a command it added" "$?" "the menu entry waits for the next session"

counted
