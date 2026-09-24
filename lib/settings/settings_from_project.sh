#!/usr/bin/env bash

# The project a hook is working in, as the payload names it. A directory that
# is not there leaves the one the hook was run in.
settings_from_project() {
  [ -n "$1" ] && [ -d "$1" ] || return 0
  PLUGIN_PROJECT="$1"
}
