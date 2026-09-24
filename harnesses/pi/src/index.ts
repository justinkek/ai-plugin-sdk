import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type ExtensionAPI = { on: (event: string, handler: (event: any, ctx: any) => any) => void };

// The hooks this plugin registers, by the event each one answers to.
const registered: Record<string, string[]> = {{hooks-by-event}};

const hooks = join(dirname(fileURLToPath(import.meta.url)), "..", "hooks");
const notes = mkdtempSync(join(tmpdir(), "{{name}}-notes-"));
const session = "pi";
let started = false;

type Spawned = { output: string; status: number; complaint: string };

// Run through bash, as every other harness does, so a script that lost its
// executable bit on the way still runs.
function spawned(script: string, payload: Record<string, unknown>, cwd?: string): Spawned {
	try {
		const output = execFileSync("bash", [join(hooks, script)], {
			input: JSON.stringify({ session_id: session, ...payload }),
			env: { ...process.env, {{prefix}}_STOP_NOTE_DIRECTORY: notes },
			encoding: "utf8",
			stdio: ["pipe", "pipe", "pipe"],
			cwd,
		});
		return { output: output.trim(), status: 0, complaint: "" };
	} catch (failed: any) {
		return {
			output: String(failed?.stdout ?? "").trim(),
			status: typeof failed?.status === "number" ? failed.status : 1,
			complaint: String(failed?.stderr ?? "").trim(),
		};
	}
}

function spawnHook(script: string, payload: Record<string, unknown>): string {
	const run = spawned(script, payload);
	return run.status === 0 ? run.output : "";
}

// A hook may answer with JSON meant for a harness that reads it; Pi shows text.
function said(output: string): string {
	if (!output.startsWith("{")) return output;
	try {
		const answer = JSON.parse(output);
		return answer?.hookSpecificOutput?.additionalContext ?? answer?.systemMessage ?? "";
	} catch {
		return output;
	}
}

function ran(event: string, payload: Record<string, unknown>): string[] {
	return (registered[event] ?? []).map((script) => said(spawnHook(script, { hook_event_name: event, ...payload })));
}

export type Decision = { decision: "allow" | "ask" | "deny" | ""; reason: string };

// What one hook decided about a tool call: the envelope's permission decision,
// or a block when it exited 2, which is how a hook refuses without JSON.
export function decisionOf(run: Spawned): Decision {
	if (run.status === 2) return { decision: "deny", reason: run.complaint || run.output };
	if (run.status !== 0 || !run.output.startsWith("{")) return { decision: "", reason: "" };
	try {
		const answer = JSON.parse(run.output)?.hookSpecificOutput;
		const decision = answer?.permissionDecision;
		if (decision !== "allow" && decision !== "ask" && decision !== "deny") return { decision: "", reason: "" };
		return { decision, reason: String(answer?.permissionDecisionReason ?? "") };
	} catch {
		return { decision: "", reason: "" };
	}
}

// A deny from any hook stands whatever another one allowed, and an ask outranks
// an allow. The order the hooks ran in decides nothing.
const strictness = ["", "allow", "ask", "deny"];
export function strictest(decisions: Decision[]): Decision {
	return decisions.reduce<Decision>(
		(held, next) => (strictness.indexOf(next.decision) > strictness.indexOf(held.decision) ? next : held),
		{ decision: "", reason: "" },
	);
}

// Pi names its tools and their arguments its own way. A hook is written against
// the names every other harness sends, so the call is handed over in those.
const toolNames: Record<string, string> = { bash: "Bash", read: "Read", edit: "Edit", write: "Write", grep: "Grep", find: "Glob", ls: "LS" };

export function toolCallPayload(toolName: string, input: any, cwd: string): Record<string, unknown> {
	const edits: any[] = Array.isArray(input?.edits) ? input.edits : [];
	const onAFile = toolName === "read" || toolName === "edit" || toolName === "write";
	return {
		hook_event_name: "PreToolUse",
		tool_name: toolNames[toolName] ?? toolName,
		cwd,
		tool_input: {
			...input,
			...(onAFile && typeof input?.path === "string" ? { file_path: input.path } : {}),
			...(edits.length > 0
				? {
						old_string: edits.map((edit) => edit?.oldText ?? "").join("\n"),
						new_string: edits.map((edit) => edit?.newText ?? "").join("\n"),
					}
				: {}),
		},
	};
}

function textOf(message: any): string {
	const content = message?.content ?? "";
	if (typeof content === "string") return content;
	return content
		.filter((part: any) => part?.type === "text")
		.map((part: any) => part.text)
		.join("\n");
}

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async () => {
		// The session start hooks speak once, when the first turn of the session starts.
		const opening = started ? [] : ran("SessionStart", {});
		started = true;
		const content = [...opening, ...ran("UserPromptSubmit", {})].filter(Boolean).join("\n");
		return content ? { message: { customType: "{{name}}", content, display: true } } : undefined;
	});

	// Pi stops at the first extension that blocks a call and lets nothing after
	// it undo that, so a deny from this plugin stands against every other
	// plugin's. What is left to decide here is this plugin's own hooks.
	pi.on("tool_call", async (event: any, ctx: any) => {
		const scripts = registered.PreToolUse ?? [];
		if (scripts.length === 0) return undefined;
		const cwd = ctx?.cwd ?? process.cwd();
		const payload = toolCallPayload(event?.toolName ?? "", event?.input ?? {}, cwd);
		const held = strictest(scripts.map((script) => decisionOf(spawned(script, payload, cwd))));
		if (held.decision === "deny") return { block: true, reason: held.reason };
		if (held.decision !== "ask") return undefined;
		const approved = ctx?.hasUI ? await ctx.ui.confirm("{{display}} asks first", held.reason) : false;
		return approved ? undefined : { block: true, reason: held.reason };
	});

	pi.on("turn_end", async (event: any) => {
		// Pi hands over the turn's reply; the stop hooks read a transcript, so
		// it is written out as one.
		const transcript = join(notes, "turn.jsonl");
		writeFileSync(transcript, `${JSON.stringify({ type: "assistant", message: { content: [{ type: "text", text: textOf(event?.message) }] } })}\n`);
		ran("Stop", { transcript_path: transcript });
	});
}
