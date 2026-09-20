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

counted
