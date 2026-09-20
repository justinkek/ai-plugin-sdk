#!/usr/bin/env bash

# Leaves the mark, and says whether it was already there.
plugin_mark_once() {
  plugin_marked "$1" && return 0
  plugin_mark "$1"
  return 1
}
