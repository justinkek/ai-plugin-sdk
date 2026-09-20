#!/usr/bin/env bash

# Where this plugin keeps its own things. Not a function: every other file in
# here reads these, so they are set once, first.
#
# The libraries sit at <plugin>/hooks/lib, so the plugin's own directory is two
# above them wherever the install put it. One fork, not three: a hook may be run
# by a relative path, so the directory is resolved once.
PLUGIN_LIB="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
PLUGIN_ROOT="${PLUGIN_LIB%/*/*}"

# The build writes this from the plugin's manifest. It is the only thing in lib/
# that knows a plugin's name.
. "$PLUGIN_LIB/plugin-manifest.sh"

plugin_named_home="${PLUGIN_PREFIX}_HOME"
PLUGIN_HOME="${!plugin_named_home:-$HOME/.$PLUGIN_NAME}"
PLUGIN_SETTINGS="$PLUGIN_HOME/settings"
PLUGIN_STATE="$PLUGIN_HOME/state"
