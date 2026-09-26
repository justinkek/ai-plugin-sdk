#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

# Every merge to main is a release, so a change an install receives has to
# raise the version. A change to the README, the tests or the example plugin
# reaches nobody, so it asks for nothing.
printf "Test group: what the check counts as reaching an install\n"

CHECK="$SDK/tests/version-changed"

[ -x "$CHECK" ]
assert "the check is there and runnable" "$?" "CI runs a file that is not there"

# A repository of its own, so nothing here depends on this branch's history.
repo="$WORK/release"
git init --quiet --initial-branch=main "$repo"
git -C "$repo" config user.email test
git -C "$repo" config user.name test

mkdir -p "$repo/tests" "$repo/lib" "$repo/builder"
cp "$CHECK" "$repo/tests/version-changed"
cp "$SDK/build" "$repo/build"
cp -R "$SDK/builder/." "$repo/builder/"
printf 'x\n' > "$repo/lib/something.sh"
printf 'x\n' > "$repo/README.md"
printf '{"version":"1.0.0"}\n' > "$repo/package.json"
git -C "$repo" add --all
git -C "$repo" commit --quiet --message base

printf 'changed\n' >> "$repo/README.md"
git -C "$repo" checkout --quiet -B branch main
git -C "$repo" commit --quiet --all --message "readme only"
bash "$repo/tests/version-changed" main >/dev/null 2>&1
assert "a change to the README alone needs no new version" "$?" \
  "a page no install receives is treated as a release"

git -C "$repo" checkout --quiet main
git -C "$repo" branch --quiet --delete --force branch
printf 'changed\n' >> "$repo/lib/something.sh"
git -C "$repo" checkout --quiet -B branch main
git -C "$repo" commit --quiet --all --message "a library"
bash "$repo/tests/version-changed" main >/dev/null 2>&1
outcome="$?"
[ "$outcome" != "0" ]
assert "a change to a library does" "$?" \
  "a hook every install runs changed and the version stayed put"

jq --tab '.version = "1.0.1"' "$repo/package.json" > "$repo/next" && mv "$repo/next" "$repo/package.json"
git -C "$repo" commit --quiet --all --message "bump"
bash "$repo/tests/version-changed" main >/dev/null 2>&1
assert "and passes once the version moves" "$?" "a raised version is still refused"

jq --tab '.version = "0.9.0"' "$repo/package.json" > "$repo/next" && mv "$repo/next" "$repo/package.json"
git -C "$repo" commit --quiet --all --message "backwards"
bash "$repo/tests/version-changed" main >/dev/null 2>&1
outcome="$?"
[ "$outcome" != "0" ]
assert "a version that goes backwards is refused" "$?" "it shipped a number somebody already has"

counted
