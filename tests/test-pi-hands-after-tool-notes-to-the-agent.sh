#!/usr/bin/env bash

# Pi's tool_result is the after_tool event: what a hook registered on it says
# is added to the result the agent reads. The built extension is loaded in Node
# with one stub hook in place of the plugin's own, and handed a tool result.

. "$(dirname "$0")/harness.sh"

printf "Test group: Pi hands what an after_tool hook says to the agent\n"

EXTENSION="$BUILT/pi/src/index.ts"
if [ ! -f "$EXTENSION" ]; then
  printf "  SKIP  this plugin has no Pi install\n"
  counted
  exit $?
fi
if ! command -v node >/dev/null 2>&1 || ! node --experimental-strip-types --eval '' 2>/dev/null; then
  printf "  SKIP  no Node that runs TypeScript here\n"
  counted
  exit $?
fi

probe="$WORK/pi-probe"
mkdir -p "$probe/src" "$probe/hooks"
cp -R "$BUILT/pi/hooks/lib" "$probe/hooks/lib"
sed 's|^const registered: Record<string, string\[\]> = .*;$|const registered: Record<string, string[]> = {"PostToolUse":["note.sh"]};|' \
  "$EXTENSION" > "$probe/src/index.ts"
cat > "$probe/hooks/note.sh" <<'HOOK'
#!/usr/bin/env bash
payload="$(cat)"
tool="$(printf '%s' "$payload" | jq --raw-output '.tool_name')"
event="$(printf '%s' "$payload" | jq --raw-output '.hook_event_name')"
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"noted %s"}}\n' "$event" "$tool"
HOOK

cat > "$probe/run.mjs" <<'RUN'
const handlers = {};
const extension = (await import(process.argv[2])).default;
extension({ on: (event, handler) => { handlers[event] = handler; } });
const result = await handlers.tool_result(
  { toolName: "write", input: { path: "a.sh", content: "x=1" }, content: [{ type: "text", text: "written" }] },
  { cwd: process.cwd() },
);
console.log(JSON.stringify(result));
RUN

answer="$(node --experimental-strip-types --no-warnings "$probe/run.mjs" "$probe/src/index.ts" 2>&1)"

printf '%s' "$answer" | jq --exit-status '.content[0].text == "written"' >/dev/null 2>&1
assert "the tool's own result is kept" "$?" "got '$answer'"

printf '%s' "$answer" | jq --exit-status '.content[1].text == "noted Write"' >/dev/null 2>&1
assert "and the hook's note follows it, naming the tool as every client does" "$?" "got '$answer'"

counted
