#!/usr/bin/env bash

# Read when a note is actually written or taken, not on every hook that sources
# this file for something else.
plugin_notes() {
  [ -n "$PLUGIN_NOTES" ] || PLUGIN_NOTES="$(setting_value STOP_NOTE_DIRECTORY)"
}
