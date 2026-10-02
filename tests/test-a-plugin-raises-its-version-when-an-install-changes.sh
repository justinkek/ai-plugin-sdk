#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# A plugin's pull request raises its version when an install would receive the
# change, and needs no new version when nothing installed changes. This makes a
# plugin repository of its own, since the check reads its git history.
printf "Test group: a change an install receives asks for a new version\n"

repository="$WORK/versioned"
"$SDK/new-plugin" "$repository" someone/versioned >/dev/null
"$SDK/build" "$repository" >/dev/null
git -C "$repository" init --quiet --initial-branch=main
git -C "$repository" -c user.name=test -c user.email=test@example.com add --all
git -C "$repository" -c user.name=test -c user.email=test@example.com commit --quiet --message base
git -C "$repository" checkout --quiet -b change

commit() {
  git -C "$repository" -c user.name=test -c user.email=test@example.com add --all
  git -C "$repository" -c user.name=test -c user.email=test@example.com commit --quiet --message "$1"
}
checked() { "$SDK/version-changed" "$repository" main >/dev/null 2>&1; }
set_version() {
  jq --tab --arg v "$1" '.version = $v' "$repository/plugin.json" > "$WORK/plugin.json.new" \
    && mv "$WORK/plugin.json.new" "$repository/plugin.json"
}

printf 'more words\n' >> "$repository/README.md"
commit "a readme"
checked
assert "a README change needs no new version" "$?" "it asked for one"

printf 'Keep it short.\n' >> "$repository/rules/reply-shape.md"
"$SDK/build" "$repository" >/dev/null
commit "a rule"
checked
[ "$?" != "0" ]
assert "a rule that reaches distributions/ without a new version is refused" "$?" \
  "an install would keep the old rule under the same number"

set_version 0.1.1
"$SDK/build" "$repository" >/dev/null
commit "raise it"
checked
assert "and passes once the version is raised" "$?" "it still refused"

set_version 0.0.9
commit "lower it"
checked
[ "$?" != "0" ]
assert "a version lower than the base is refused" "$?" "it names a version somebody already has"

printf "\nTest group: the two files holding the version agree\n"

set_version 0.1.1
printf '{"name":"versioned","version":"0.2.0"}\n' > "$repository/package.json"
commit "disagree"
checked
[ "$?" != "0" ]
assert "plugin.json and package.json naming different versions is refused" "$?" \
  "the update check would read a version the build never wrote"

printf "\nTest group: new-plugin wires the check into CI\n"

grep --quiet --fixed-strings 'ai-plugin-sdk/version-changed' "$repository/.github/workflows/tests.yml"
assert "the workflow new-plugin writes runs it on a pull request" "$?" "nothing asks for a new version"

counted
