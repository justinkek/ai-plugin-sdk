#!/usr/bin/env bash

# A harness reads the envelope or it reads the text. Setting <PREFIX>_PLAIN asks
# for the text, which is what a person piping a hook by hand wants, and what the
# build reads when it renders the reload skill.
hook_plain() {
  local named="${PLUGIN_PREFIX}_PLAIN"
  [ -n "${!named-}" ]
}
