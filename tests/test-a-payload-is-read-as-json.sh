#!/usr/bin/env bash

. "$(dirname "$0")/harness.sh"

LIB="$BUILT/$(distributions | head -1)/hooks/lib"

# Two readers, and they have to agree: jq where a machine has it, and a walk
# over the text where it does not.
with_jq() { bash -c ". \"$LIB/payload.sh\"; hook_field \"\$1\" \"\$2\"" _ "$1" "$2"; }

NOJQ="$WORK/nojq"
mkdir -p "$NOJQ"
for binary in bash awk sed grep head tr cat env printf; do
  [ -x "$(command -v "$binary")" ] && ln -sf "$(command -v "$binary")" "$NOJQ/$binary"
done
without_jq() {
  env PATH="$NOJQ" bash -c ". \"$LIB/payload.sh\"; hook_field \"\$1\" \"\$2\"" _ "$1" "$2"
}

reads() {
  local payload="$1" key="$2" want="$3" label="$4" got

  got="$(with_jq "$payload" "$key")"
  [ "$got" = "$want" ]
  assert "$label" "$?" "with jq it read '$got', not '$want'"

  got="$(without_jq "$payload" "$key")"
  [ "$got" = "$want" ]
  assert "and the same without jq" "$?" "without jq it read '$got', not '$want'"
}

printf "Test group: the key a hook asks for, in whichever spelling arrived\n"

reads '{"session_id":"abc"}' session_id abc "session_id"
reads '{"sessionId":"abc"}' session_id abc "sessionId, asked for in snake case"
reads '{"a":"x","hook_event_name":"Stop"}' hook_event_name Stop "a key that is not first"

printf "\nTest group: a key at the top level, not one nested under another\n"

# A nested key winning writes a turn's notes under the wrong session, silently.
reads '{"session_id":"real","outer":{"session_id":"nested"}}' session_id real \
  "the top-level one wins when the nested one comes after"
reads '{"outer":{"session_id":"nested"},"session_id":"real"}' session_id real \
  "and when it comes before"
reads '{"outer":{"only":{"session_id":"deep"}}}' session_id "" \
  "a key only ever nested is a key that was not sent"

printf "\nTest group: a value is whole\n"

reads '{"prompt":"he said \"hello\" loudly"}' prompt 'he said "hello" loudly' \
  "a quote inside the value does not end it"
reads '{"prompt":"a {brace} and a [bracket]"}' prompt 'a {brace} and a [bracket]' \
  "braces inside a string are not structure"
reads '{"transcript_path":"/tmp/a b/x.jsonl"}' transcript_path '/tmp/a b/x.jsonl' \
  "a path with a space"

printf "\nTest group: what carries no quotes, and what was not sent\n"

reads '{"stop_hook_active":true}' stop_hook_active true "true"
reads '{"stopHookActive":false}' stop_hook_active false "false, in the other spelling"
reads '{"a":1,"n":42}' n 42 "a number"
reads '{"session_id":null}' session_id "" "an explicit null reads as not sent"
reads '{"nope":"x"}' session_id "" "a key that is not there"

counted
