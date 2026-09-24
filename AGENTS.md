# Working in this repository

(audience: agents)

This is the SDK a plugin runs to build its distributions. It knows harnesses and
clients. It does not know any plugin, and a test fails when something here names
one.

## Compatibility is the SDK's

Where a plugin can be installed, and what runs when it is, is true of the
client whatever plugin is built for it. A plugin writes none of it: the build
writes its `COMPATIBILITY.md` from `compatibility.json` and what each
`client.json` says it runs.

## Every merge is a release

A plugin clones this repository and names no ref, so whatever the default
branch points at is what it gets. Trunk-based: short branches,
merged often, and every one of them raises the version in `package.json`.

CI fails a pull request whose version matches its base, or whose version went
backwards. Run it yourself with `tests/version-changed`. It is not in
`tests/run-tests`, because a branch is allowed to be mid-change; the merge is
what has to carry the bump.

Which digit moves is one question: **would a plugin built against the last
version break on this one?**

| | When |
| --- | --- |
| minor, `0.X.0` | yes — a function moved between files in `lib/`, a name changed, `build` needs something new beside it, `plugin.json` wants a field it did not want before |
| patch, `0.2.X` | no — a fix that leaves the same names in the same places, a function added, a page, a test, this file |

0.2.0 was a minor because `installed_version`, `apply_migrations` and
`plugin_mark*` moved out of `lib/settings.sh` into `lib/state.sh`, and a hook
sourcing `settings.sh` to call `installed_version` breaks. The cloud
`refresh.sh` was doing exactly that, and the tests caught it.

Adding something is a patch here rather than a minor, because the only question
a plugin author is asking is whether their plugin still works.

## Before you push

    tests/run-tests

They build `example/` and check what came out. To check a real plugin instead:

    tests/run-tests ../that-plugin

Every push and every pull request runs them, on a machine with shellcheck and
jq installed, and type-checks the Pi extension the build writes — nothing else
compiles it. See `.github/workflows/tests.yml`.

One of them runs shellcheck, and skips with a note when it is not installed. A
`# shellcheck disable=` with no reason on the line above it fails that test:
silencing a warning is a decision, so it is written down.

## Where a change belongs

| Change | File |
| --- | --- |
| what a hook script can call | `lib/<subject>/<function>.sh`, named by the file it is in |
| what sourcing one subject pulls in | `lib/<subject>.sh`, which names its parts and defines nothing |
| how a harness is told about a hook | `harnesses/<harness>/harness.json` |
| what a harness carries besides the registration | a file under `harnesses/<harness>/` |
| the steps for one client | `clients/<client>/<page>.md` |
| what one of the four skills says | `skills/<name>/body.md` |
| a setting every plugin gets | `lib/settings.json` |
| what a plugin's hooks may not be called | `tests/test-nothing-clobbers-a-library-name.sh` |
| the shell a hook needs | `lib/shell.sh` |
| the paths every setting reads | `lib/settings/paths.sh`, the one file there that is not a function |
| which parts get copied where | `builder/contents.sh` |
| how a page or a README is written | `builder/pages.sh` |
| how a skill is rendered | `builder/skills.sh` |
| what the manifest is read into | `builder/manifest.sh` |
| what a client runs, and its caveat | `clients/<client>/client.json` |
| which products exist and which have a client | `compatibility.json` |

## How the build is put together

`build` is the loop: read the manifest, then one folder per harness the plugin
names a client of. `builder/` holds the parts, one file to a subject, and the
loop sources them.

The rule inside `lib/` is one function to a file, because a plugin author goes
looking for one function. `builder/` is one subject to a file instead, because
whoever opens it is changing the build and wants the subject together.

## What a plugin's hooks/ holds

Hooks, which a harness runs, and files its hooks source, which nothing runs. The
second kind ends `-lib.sh`, and `migrations.sh` is one of them under another
name. The build moves both to `hooks/lib/`, beside the SDK's own, so what is
left in `hooks/` is what the manifest registers and nothing else.

## How the build reads a plugin

`plugin.json` is the only manifest. `hooks` is turned into each harness's own
registration; `settings` is turned into `hooks/lib/plugin-manifest.sh`, which is
what `lib/settings.sh` reads instead of knowing a plugin; `clients` decides which
harnesses are built at all.

A page is the plugin's where it has one and the SDK's otherwise, so a plugin
overrides one client's steps without carrying the other six.

## Leaving the name open

Everything the SDK ships is written with the plugin's name left open, and the
build fills it in:

| Written | Filled with |
| --- | --- |
| `{{name}}` | the plugin's name |
| `{{display}}` | its display name |
| `{{version}}` | its version |
| `{{repository}}` | its `owner/repo` |
| `{{prefix}}` | its name, upper case, dashes as underscores |
| `{{home}}` | `~/.<name>` |
| `{{hooks}}` | how many hook commands it registers |
| `{{session-start}}` | the first script it registers for `SessionStart` |
| `{{root}}` | how this harness names the plugin's directory |
| `{{hooks-by-event}}` | its hooks map, for a harness that spawns them itself |

A test fails on anything the build writes that still holds one.

## What a harness declares

`harness.json` says which clients it serves, what it ships, how a command names
the plugin's root, and whether it reads the answer envelope or the text a hook
prints. Nothing else in the build names a harness.

## Facts the SDK carries

Each of these was a real failure on a real client, and something here holds it:

| Fact | What holds it |
| --- | --- |
| a payload key arrives in either spelling | `lib/payload.sh` |
| a payload is JSON, so a nested key is not the one asked for | `lib/payload/hook_field.sh`, jq where there is jq, `payload_scanned` where there is not |
| some clients discard plain text from a hook | `lib/say.sh` |
| a reply may come with no transcript at all | `lib/reply.sh` |
| a hook without the executable bit is not run | every registration runs `bash "<path>"` |
| a harness may read the text rather than the envelope | `reads` in `harness.json`, and `<PREFIX>_PLAIN` |
| a cloud install must merge rather than append | `harnesses/claude-code-cloud/merge-settings.sh` |
| two plugins must not drain each other's notes | `lib/notes.sh`, under the plugin's own home |
| a shell too old fails with a sentence, not a syntax error | `lib/shell.sh`, sourced by both roots of the graph |
| a plugin with no session start hook still gets a manifest bash can read | `builder/contents.sh` |
| and its cloud checkout is still refreshed at session start | `registration` in `builder/harnesses.sh` |
| one plugin allowing a tool call never undoes another refusing it | the rule below |

## A deny outranks an allow

Two plugins that restrict tool calls are installed side by side, and one hook
allowing a call must never undo another refusing it. Deny outranks ask, and ask
outranks allow, whichever plugin each came from and whatever order they ran in.

Claude Code and Codex run every registered hook on a call and decide that
themselves, so the SDK only registers. Pi hands the call to each extension in
turn, stops at the first one that blocks and lets nothing after it undo that, so
across plugins the rule holds there as well. What the SDK decides is how one
plugin's own hooks add up on Pi: `harnesses/pi/src/index.ts` takes the
strictest, and asks a person where the strictest is an ask, blocking when
nobody is there to answer. `tests/test-a-deny-outranks-an-allow.sh` holds it.

## Writing

Plain English, no metaphors, and a worked example instead of a description of
one. Every page opens with `(audience: humans)` or `(audience: agents)` under
its heading. Where a page written for one holds a paragraph the other acts on,
that paragraph opens with the mark for whoever acts on it, and it lasts one
paragraph.
