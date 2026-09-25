# ai-plugin-sdk

<h2 align="center">write once, plugin anywhere</h2>

(audience: humans)

- Create plugins for Claude, Codex, Pi, etc. from a single source.
- Comes with specific install/update/uninstall/settings instructions for each client, so you can focus on features, not harness infrastructure.

<details>
<summary>Supported clients</summary>

**Anthropic**

| Product     | Surface     | Where it runs | Support   |
| ----------- | ----------- | ------------- | --------- |
| Claude Chat | Web GUI     | Hosted        | Partial   |
| Claude Chat | Desktop GUI | Hosted        | Partial   |
| Claude Chat | Mobile GUI  | Hosted        | Partial   |
| Cowork      | Web GUI     | Hosted        | Supported |
| Cowork      | Desktop GUI | Hosted        | Supported |
| Cowork      | Mobile GUI  | Hosted        | Supported |
| Claude Code | Web GUI     | Hosted        | Supported |
| Claude Code | Desktop GUI | Hosted        | Supported |
| Claude Code | Mobile GUI  | Hosted        | Supported |
| Claude Code | Desktop GUI | Local         | Supported |
| Claude Code | CLI         | Local         | Supported |

**OpenAI**

| Product      | Surface       | Where it runs | Support       |
| ------------ | ------------- | ------------- | ------------- |
| ChatGPT Chat | Web GUI       | Hosted        | Not verified  |
| ChatGPT Chat | Desktop GUI   | Hosted        | Not verified  |
| ChatGPT Chat | Mobile GUI    | Hosted        | Not verified  |
| ChatGPT Work | Web GUI       | Hosted        | Not supported |
| ChatGPT Work | Desktop GUI   | Local         | Not verified  |
| ChatGPT Work | Desktop GUI   | Hosted        | Not supported |
| ChatGPT Work | Mobile GUI    | Hosted        | Not supported |
| Codex        | Web GUI       | Hosted        | Not supported |
| Codex        | Desktop GUI   | Local         | Supported     |
| Codex        | Desktop GUI   | Hosted        | Not supported |
| Codex        | CLI           | Local         | Supported     |
| Codex        | IDE extension | Local         | Not supported |

**ZCode**

| Product | Surface     | Where it runs | Support   |
| ------- | ----------- | ------------- | --------- |
| ZCode   | Desktop GUI | Local         | Supported |

**Pi**

| Product | Surface | Where it runs | Support |
| ------- | ------- | ------------- | ------- |
| Pi      | CLI     | Local         | Partial |

**What is missing where it says Partial**

- **Claude Chat** - No hook runs, so a plugin reaches a conversation only through its skills.
- **Cowork** - Every conversation runs on Anthropic's servers, whichever app starts it.
- **Claude Code (Cloud)** - The container is rebuilt for every session, so a setting kept goes in an environment variable.
- **Codex** - No hook runs until a person has trusted it, and an update un-trusts them all.
- **Pi** - Skills load from ~/.agents/skills and an extension puts none there, so a plugin's skills do not arrive.

</details>

## Getting started

1. Ensure your plugin has the following structure, and add `plugin.json`

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
    "SessionStart": ["say-the-rule.sh"],
    "UserPromptSubmit": ["replay-notes.sh"],
    "Stop": ["note-a-long-reply.sh"]
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

| Source this       | What it gives                                                                 |
| ----------------- | ----------------------------------------------------------------------------- |
| `lib/payload.sh`  | `hook_field`, which reads a key in either spelling, whichever harness sent it |
| `lib/say.sh`      | `hook_say` and `hook_say_aloud`, the one answer shape every client reads      |
| `lib/reply.sh`    | `hook_last_reply`, out of the payload or out of a transcript                  |
| `lib/notes.sh`    | `stop_note_record` and `stop_note_take`, in a directory this plugin owns      |
| `lib/settings.sh` | `setting_value`, `setting_on`, `setting_is_set`, `settings_from_project`      |
| `lib/state.sh`    | `installed_version`, `apply_migrations`, `plugin_mark`                        |

Each of those is a directory beside it with one function to a file, so
`setting_value` is in `lib/settings/setting_value.sh`. A subject sources what it
needs, so sourcing `notes.sh` gets you `settings.sh` and `state.sh` as well.

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

2. Clone `ai-plugin-sdk`, and run it in your plugin's directory:

```
    git clone https://github.com/justinkek/ai-plugin-sdk
    cd <path to your-plugin>
    <path to ai-plugin-sdk>/build
```

`ai-plugin-sdk` reads `your-plugin/plugin.json` and writes to:

- `your-plugin/distributions/`
- `your-plugin/INSTALL.md`

3. Commit both files so that agents can easily install your plugin.

## Plugins built with `ai-plugin-sdk`

- [unsolicited-text](https://github.com/justinkek/unsolicited-text)

## Tests

    tests/run-tests [plugin-directory]

With no directory it runs against `example/`, the plugin in this repository.
Point it at your own and the same tests run against that.
