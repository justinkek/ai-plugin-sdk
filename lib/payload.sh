#!/usr/bin/env bash

# What a harness handed the hook. One of the two files a hook can enter
# through, so the shell is checked here.
#
# One function to a file, in payload/. This names them and nothing else.

. "${BASH_SOURCE[0]%/*}/shell.sh"
. "${BASH_SOURCE[0]%/*}/payload/payload_scanned.sh"
. "${BASH_SOURCE[0]%/*}/payload/hook_field.sh"
