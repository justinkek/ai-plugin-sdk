# ai-plugin-sdk

(audience: humans)

A plugin that prints something into a session, refuses an edit against a rule,
or carries a note to the next prompt has to be installed somewhere. Doing that
by hand for seven clients costs more than the plugin does.

This is the part that is the same every time. You write a manifest, some hook
scripts and whatever your plugin is for. The SDK writes the folders each client
installs from: the hook registrations, the marketplace manifests, the install,
update, uninstall and settings pages, and the four skills that run them.

## Using it

Clone it, and run it in your plugin's directory:

    git clone https://github.com/justinkek/ai-plugin-sdk
    path/to/ai-plugin-sdk/build

It reads `plugin.json` and writes `distributions/`, one folder per harness,
plus `INSTALL.md`. Commit both: an install fetches files from your repository,
so what is committed is what a person gets.

## What a plugin holds

    any-plugin
    ├── plugin.json     name, version, clients, hooks by event, settings and defaults
    ├── hooks/          its own scripts, sourcing lib/ beside them
    ├── rules/          whatever it puts into a session, if anything
    ├── skills/         its own, beside the four the SDK generates
    ├── clients/        a support page per client, and any page it writes itself
    ├── install-page/   the prose around the install table
    ├── distributions/  generated, committed
    └── tests/          its own behaviour only

## The manifest

```json
{
  "name": "example-plugin",
  "version": "0.1.0",
  "description": "What it is for.",
  "repository": "you/example-plugin",
  "ai-plugin-sdk": { "version": "0.6.1" },
  "ships": ["rules"],
  "hooks": {
    "SessionStart": ["say-the-rule.sh"],
    "UserPromptSubmit": ["replay-notes.sh"],
    "Stop": ["note-a-long-reply.sh"]
  },
  "settings": {
    "LINE_CEILING": { "kind": "count", "default": "8", "says": "the most lines a reply may hold" }
  }
}
```

`ai-plugin-sdk.version` is the oldest SDK that can build this plugin. A build
from an older copy stops and says so rather than writing folders by rules it
has not got. Leave it out and any copy builds it. The version that did build
is written at the foot of `INSTALL.md`.

`clients` is optional. Leave it out and the plugin is built for every client the
SDK knows, minus any it could not reach - a client running neither hooks nor
skills. Name it only to narrow that. `hooks` is read by every harness: each one registers those
scripts the way it wants to be told. `settings` is read by the settings library
and by the settings skill, so a key you declare is a key a person is offered.

A setting has a `kind`: `count`, `switch`, `choice` (with `values`), or `text`.
A value the kind does not take is refused and the default stands, because a
hook that reads a value it has no rule for is worse than one reading the
default. `{state}` and `{home}` in a default are filled in at run time.

## What a hook can read

Every hook script gets `hooks/lib/` beside it. Source the subject you need:

| Source this | What it gives |
| --- | --- |
| `lib/payload.sh` | `hook_field`, which reads a key in either spelling, whichever harness sent it |
| `lib/say.sh` | `hook_say` and `hook_say_aloud`, the one answer shape every client reads |
| `lib/reply.sh` | `hook_last_reply`, out of the payload or out of a transcript |
| `lib/notes.sh` | `stop_note_record` and `stop_note_take`, in a directory this plugin owns |
| `lib/settings.sh` | `setting_value`, `setting_on`, `setting_is_set` |
| `lib/state.sh` | `installed_version`, `apply_migrations`, `plugin_mark` |

Each of those is a directory beside it with one function to a file, so
`setting_value` is in `lib/settings/setting_value.sh`. A subject sources what it
needs, so sourcing `notes.sh` gets you `settings.sh` and `state.sh` as well.

## Which clients it knows

| Client | Harness |
| --- | --- |
| Claude Code, on your machine | `claude` |
| ZCode | `claude` |
| Claude Chat | `claude` |
| Claude Cowork | `claude` |
| Claude Code, in the cloud | `claude-code-cloud` |
| Codex | `codex` |
| Pi | `pi` |

A page any of them ships is the SDK's. Put a file of the same name under your
plugin's `clients/<client>/` and yours is used instead.

## Tests

    tests/run-tests [plugin-directory]

With no directory it runs against `example/`, the plugin in this repository.
Point it at your own and the same tests run against that.
