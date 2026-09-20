#!/usr/bin/env bash

# What the agent said last, however this harness hands it over.
#
# One function to a file, in reply/.

. "${BASH_SOURCE[0]%/*}/payload.sh"
. "${BASH_SOURCE[0]%/*}/reply/hook_last_reply.sh"
