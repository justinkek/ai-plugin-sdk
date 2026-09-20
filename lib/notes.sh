#!/usr/bin/env bash

# A note one hook writes and another reads back on the next prompt. The
# directory is this plugin's own, so two plugins installed together do not
# drain each other's notes.

. "${BASH_SOURCE[0]%/*}/settings.sh"

apply_migrations

# Read when a note is actually written or taken, not on every hook that sources
# this file for something else.
plugin_notes() {
  [ -n "$PLUGIN_NOTES" ] || PLUGIN_NOTES="$(setting_value STOP_NOTE_DIRECTORY)"
}

stop_note_record() {
  local session_id="$1" note="$2" notes_file
  [ -n "$session_id" ] && [ -n "$note" ] || return 0
  plugin_notes
  notes_file="$PLUGIN_NOTES/$session_id.stop-notes"
  mkdir -p "$PLUGIN_NOTES"
  printf '%s\n' "$note" >> "$notes_file"
}

stop_note_take() {
  local session_id="$1" notes_file
  plugin_notes
  notes_file="$PLUGIN_NOTES/$session_id.stop-notes"
  [ -f "$notes_file" ] || return 0
  cat "$notes_file"
  rm -f "$notes_file"
}
