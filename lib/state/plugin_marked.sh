#!/usr/bin/env bash

# Whether a mark is there. The name is a path, so a marker per session goes
# under a directory named for what it records.
plugin_marked() { [ -f "$PLUGIN_STATE/$1" ]; }
