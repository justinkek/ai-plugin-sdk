# Working in this repository

(audience: agents)

This is the SDK a plugin runs to build its distributions. It knows harnesses and
clients. It does not know any plugin, and a test fails when something here names
one.

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

## How the build is put together

`build` is the loop: read the manifest, then one folder per harness the plugin
names a client of. `builder/` holds the parts, one file to a subject, and the
loop sources them.

The rule inside `lib/` is one function to a file, because a plugin author goes
looking for one function. `builder/` is one subject to a file instead, because
whoever opens it is changing the build and wants the subject together.

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

## Writing

Plain English, no metaphors, and a worked example instead of a description of
one. Every page opens with `(audience: humans)` or `(audience: agents)` under
its heading. Where a page written for one holds a paragraph the other acts on,
that paragraph opens with the mark for whoever acts on it, and it lasts one
paragraph.
