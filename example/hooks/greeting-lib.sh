#!/usr/bin/env bash

# A file the plugin's own hooks source. Nothing registers it, and the build
# puts it beside the SDK's libraries rather than leaving it among the hooks.
greeting_for() { printf 'Rules for this session%s.' "$1"; }
