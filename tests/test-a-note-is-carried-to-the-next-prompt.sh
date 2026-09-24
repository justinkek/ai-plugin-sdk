#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

LIB="$BUILT/$(distributions | head -1)/hooks/lib"

printf "Test group: a note is written, read back once, and gone\n"

notes() { bash -c ". \"$LIB/notes.sh\" && $1"; }

export "${PREFIX}_HOME=$WORK/notes-home"

notes 'stop_note_record s1 "the first note"'
notes 'stop_note_record s1 "the second note"'

[ "$(notes 'stop_note_take s1')" = "$(printf 'the first note\nthe second note')" ]
assert "both notes come back, in the order they were written" "$?" \
  "it read '$(notes 'stop_note_take s1')'"

[ -z "$(notes 'stop_note_take s1')" ]
assert "and the next read finds nothing" "$?" "a note would be replayed on every prompt"

printf "\nTest group: one session's notes are not another's\n"

notes 'stop_note_record s1 "for the first session"'
[ -z "$(notes 'stop_note_take s2')" ]
assert "a session with no notes reads none" "$?" "it was handed another session's note"
[ "$(notes 'stop_note_take s1')" = "for the first session" ]
assert "and the session it was written for still has it" "$?" "the wrong read took it"

printf "\nTest group: the notes are under this plugin's own directory\n"

notes 'stop_note_record s1 "somewhere"'
found="$(find "$WORK/notes-home" -name '*.stop-notes')"
[ -n "$found" ]
assert "a note is written under ${PREFIX}_HOME" "$?" "nothing was written there at all"

printf '%s' "$found" | grep --quiet --fixed-strings "$WORK/notes-home"
assert "and nowhere else" "$?" \
  "two plugins installed together would drain each other's notes"

printf "\nTest group: a directory the settings name is the one used\n"

env "${PREFIX}_HOME=$WORK/notes-home" "${PREFIX}_STOP_NOTE_DIRECTORY=$WORK/elsewhere" \
  bash -c ". \"$LIB/notes.sh\" && stop_note_record s9 \"over here\""
[ -f "$WORK/elsewhere/s9.stop-notes" ]
assert "the setting moves the notes" "$?" \
  "a harness that hands the hooks a directory of its own is ignored"

printf "\nTest group: the replay is the SDK's, so a plugin does not write one\n"

HOOKS="$BUILT/$(distributions | head -1)/hooks"

[ -f "$HOOKS/replay-notes.sh" ]
assert "the build wrote the replay hook" "$?" "every plugin would write its own"

for distribution in $(distributions); do
  for where in "$BUILT/$distribution/hooks/hooks.json" "$BUILT/$distribution/settings.json"; do
    [ -f "$where" ] || continue
    [ "$(grep --count --fixed-strings 'replay-notes.sh' "$where")" = "1" ]
    assert "$distribution registers it once" "$?" "a note would be replayed twice or not at all"
  done
done

prompted() {
  printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s","prompt":"x"}' "$1" \
    | env "${PREFIX}_HOME=$WORK/replay-home" bash "$HOOKS/replay-notes.sh"
}

env "${PREFIX}_HOME=$WORK/replay-home" \
  bash -c ". \"$LIB/notes.sh\" && stop_note_record sr \"what the last turn left\""

said="$(prompted sr)"
printf '%s' "$said" | jq --exit-status '.hookSpecificOutput.additionalContext == "what the last turn left"' >/dev/null
assert "the next prompt is given the note" "$?" "it said '$said'"

[ -z "$(prompted sr)" ]
assert "and the prompt after it is not" "$?" "the note is replayed on every prompt"

[ -z "$(prompted nothing-written)" ]
assert "a session with no note is told nothing" "$?" "it speaks up with nothing to say"

counted
