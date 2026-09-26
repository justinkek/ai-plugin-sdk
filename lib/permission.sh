#!/usr/bin/env bash

# A hook that stands between an agent and a tool call answers deny, ask or
# allow. Every hook on the same call answers, from every plugin installed, and
# the answers are merged: deny outranks ask, and ask outranks allow. One plugin
# allowing a call never lets it past another plugin refusing it.
#
# One function to a file, in permission/.

. "${BASH_SOURCE[0]%/*}/say.sh"
. "${BASH_SOURCE[0]%/*}/permission/hook_permission.sh"
. "${BASH_SOURCE[0]%/*}/permission/strongest_permission.sh"
