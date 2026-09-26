# ai-plugin-sdk

<h2 align="center">write once, plugin anywhere</h2>

(audience: humans)

- Create plugins for Claude, Codex, Pi, etc. from a single source.
- Comes with specific install/update/uninstall/settings instructions for each client, so you can focus on features, not harness infrastructure.

See [supported clients](COMPATIBILITY.md).

## Getting started

1. Clone the SDK and make a plugin with it:

```
git clone https://github.com/justinkek/ai-plugin-sdk
ai-plugin-sdk/new-plugin your-plugin you/your-plugin
```

That writes the manifest, one session start hook and the rule it prints. The
rest of the structure is yours to add as you need it:

```
your-plugin
    ├── plugin.json     name, version, clients, hooks by event, settings and defaults
    ├── hooks/          its own scripts, sourcing lib/ beside them
    ├── rules/          whatever it puts into a session, if anything
    ├── skills/         its own, beside the four the SDK generates
    ├── clients/        a support page per client, and any page it writes itself
    ├── install-page/   the prose around the install table
    ├── distributions/  generated, committed
    └── tests/          its own behaviour only
```

<details>
<summary>Details</summary>

```json
// plugin.json
{
  "name": "example-plugin",
  "version": "0.1.0",
  "description": "What it is for.",
  "repository": "you/example-plugin",
  "ai-plugin-sdk": { "version": "0.6.1" },
  "ships": ["rules"],
  "hooks": {
    "session_start": [{ "script": "say-the-rule.sh", "on": ["startup", "resume"] }],
    "before_tool": [{ "script": "guard.sh", "on": ["bash(git *)", "edit(*.sh)"] }],
    "stop": ["note-a-long-reply.sh"]
  },
  "settings": {
    "LINE_CEILING": {
      "kind": "count",
      "default": "8",
      "says": "the most lines a reply may hold"
    }
  }
}
```

## The manifest

`ai-plugin-sdk.version` is the oldest SDK that can build this plugin. A build
from an older copy stops and says so rather than writing folders by rules it
has not got. Leave it out and any copy builds it. The version that did build
is written at the foot of `INSTALL.md`.

`clients` is optional. Leave it out and the plugin is built for every client the
SDK knows, minus any it could not reach - a client running neither hooks nor
skills. Name it only to narrow that. `hooks` is read by every harness: each one registers those
scripts the way it wants to be told. `settings` is read by the settings library
and by the settings skill, so a key you declare is a key a person is offered.

## Naming hooks

`hooks` names each script under an event, by the same name on every client:
`session_start`, `prompt`, `before_tool`, `after_tool`, `permission_request`,
`stop`, `compact`, `after_compact`, `session_end`, `subagent_start`,
`subagent_stop` and `interrupt`. The build writes each client's own name for
it. A client's own event name, such as `SessionStart`, is refused, and the
build says which common name to use.

A script can be a name, or an object with an `on` list of what it runs for. On
`before_tool`, `after_tool` and `permission_request` the list names tool calls
by kind, each with an optional pattern in brackets. On every other event it
names the event's own values, such as `startup` and `resume`.

| Kind | The pattern matches |
| --- | --- |
| `bash`, `powershell` | the command, each subcommand on its own, as Claude Code matches `Bash(git *)` |
| `read`, `write`, `edit`, `multi_edit`, `notebook_edit`, `delete`, `move` | the file |
| `grep`, `glob`, `list` | the search pattern |
| `web_fetch`, `web_search` | the URL, or the query |
| `agent` | the prompt |
| `mcp` | the tool's name |

Each client's tool names for each kind are in `builder/tools/`. Where a client
filters on the tool input, the pattern becomes its own filter; where it does
not, the hook is called for every call of that kind, and `tool_entries` hands
it only the ones its `on` list asked for:

```bash
payload="$(cat)"
. "$(dirname "$0")/lib/tool.sh"
. "$(dirname "$0")/lib/permission.sh"
while IFS= read -r entry; do
  file="$(jq --raw-output .file <<< "$entry")"
  added="$(jq --raw-output .added <<< "$entry")"
  # ...decide, then refuse with: hook_permission deny "why"
done < <(tool_entries "$payload")
```

Every entry has the same fields on every client: `kind`, `tool`, `file`,
`command`, `added`, `removed`, `pattern`, `url`, `query` and `prompt`. One call
can be several entries: a Codex patch that adds one file and changes another
is two.

A setting has a `kind`: `count`, `switch`, `choice` (with `values`), or `text`.
A value the kind does not take is refused and the default stands, because a
hook that reads a value it has no rule for is worse than one reading the
default. `{state}` and `{home}` in a default are filled in at run time.

A setting is read from the environment first, then from the project's own
`.<name>/settings`, then from the person's `~/.<name>/settings`, then the
default. The project's file is the nearest one at or above the directory the
hook runs in, and a hook that has a payload can name that directory outright:

```bash
settings_from_project "$(hook_field "$payload" cwd)"
```

## What a hook can read

Every hook script gets `hooks/lib/` beside it. Source the subject you need:

| Source this         | What it gives                                                                 |
| ------------------- | ----------------------------------------------------------------------------- |
| `lib/payload.sh`    | `hook_field`, which reads a key in either spelling, whichever harness sent it |
| `lib/say.sh`        | `hook_say` and `hook_say_aloud`, the one answer shape every client reads      |
| `lib/reply.sh`      | `hook_last_reply`, out of the payload or out of a transcript                  |
| `lib/notes.sh`      | `stop_note_record` and `stop_note_take`, in a directory this plugin owns      |
| `lib/settings.sh`   | `setting_value`, `setting_on`, `setting_is_set`, `settings_from_project`      |
| `lib/state.sh`      | `installed_version`, `apply_migrations`, `plugin_mark`                        |
| `lib/permission.sh` | `hook_permission`, a deny, ask or allow on the tool call a hook was handed    |
| `lib/tool.sh`       | `tool_entries`, the tool call a hook was handed, the same on every client     |

Each of those is a directory beside it with one function to a file, so
`setting_value` is in `lib/settings/setting_value.sh`. A subject sources what it
needs, so sourcing `notes.sh` gets you `settings.sh` and `state.sh` as well.

## When two plugins disagree

A hook on a tool call answers deny, ask or allow, and every plugin installed
answers the same call. A deny outranks an ask, and an ask outranks an allow, so
a plugin that allows a call never lets it past another plugin refusing it.
Claude Code and Codex merge the answers that way themselves. On Pi the SDK runs
the hooks, and `strongest_permission` in `lib/permission.sh` is the merge.

## Which clients it knows

| Client                       | Harness             |
| ---------------------------- | ------------------- |
| Claude Code, on your machine | `claude`            |
| ZCode                        | `claude`            |
| Claude Chat                  | `claude`            |
| Claude Cowork                | `claude`            |
| Claude Code, in the cloud    | `claude-code-cloud` |
| Codex                        | `codex`             |
| Pi                           | `pi`                |

A page any of them ships is the SDK's. Put a file of the same name under your
plugin's `clients/<client>/` and yours is used instead.

</details>

2. Build it, whenever the manifest or a hook changes:

```
ai-plugin-sdk/build your-plugin
```

It reads `your-plugin/plugin.json` and writes:

- `your-plugin/distributions/` - one folder per harness, what an install copies
- `your-plugin/INSTALL.md` - how to install it, per client
- `your-plugin/COMPATIBILITY.md` - where it can be installed, and what reaches
  a session there

3. Commit all three. An install fetches files from your repository, so what is
   committed is what a person gets.

## Plugins built with `ai-plugin-sdk`

- [unsolicited-text](https://github.com/justinkek/unsolicited-text)

## Tests

    tests/run-tests [plugin-directory]

With no directory it runs against `example/`, the plugin in this repository.
Point it at your own and the same tests run against that.
