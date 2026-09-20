#!/usr/bin/env bash

# Text on standard input, as the inside of a JSON string.
hook_escaped() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r$//' -e 's/\t/\\t/g' \
    | awk 'BEGIN { ORS = "" } { if (NR > 1) printf "\\n"; printf "%s", $0 }'
}
