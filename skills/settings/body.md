---
name: settings
description: Change {{name}}'s settings
---

# {{name}} settings

Settings are stored in `{{home}}/settings.json`, one JSON object whose keys
are the keys below without the `{{prefix}}_` they carry in the environment:

```json
{
  "SOME_SWITCH": "off",
  "SOME_LIST": { "an-item": false, "another": true }
}
```

{{settings-table}}

`{{prefix}}_HOME` moves the settings file and the state under it together.

A list setting ships a list of items. Each file turns an item off with `false`
or adds one with `true`, and keeps every other item the plugin ships, so a new
version's items still arrive. Its `_SHIPPED` switch set to `off` leaves out the
shipped items, so the list is only what is turned on.

A project can hold settings of its own in `.{{name}}/settings.json` at its
root, in the same shape, and a person can hold their own for that project in
`.{{name}}/settings.local.json` beside it. The hooks read the local file
first, then the project's, then `{{home}}/settings.json`, and an environment
variable before any of them; for a list, the first of those to name an item
decides it. Write the project's file when the user wants a value for everyone
working in the project, and say that it is a file to commit. Write the local
one when they want it for themselves in this project alone, and say it is a
file to leave out of git.

An environment variable holds a list as the same JSON object a file holds:
`{{prefix}}_<LIST_KEY>='{"an-item": false}'`.

A file that holds a `{{name}}` setting as `key = value` lines is from before
the SDK wrote JSON, and no hook reads it. Offer to write each of its values
again with the steps below, then remove it.

## Before writing anything

Read the steps below. Where they say no hook runs, write no
file: follow them instead, since nothing would read what you wrote.

## How to update settings

{{how-to-write-a-setting}}

## How to apply settings

The steps below say what reads the file here, and what to do so the session
reads the new copy.

## Inform the user of their settings

Name each key the file sets, and the default above for keys that are unset / empty.

A key another setting has turned off keeps its value and says so in the parenthesis, naming the key and the value that turned it off:

{{settings-idle-example}}

## What not to do

Do not edit what a hook prints to change a value. The hook rewrites it from
whatever is configured, every time it runs.

Do not export a variable in a shell to make a change stick: it lasts as long as
that shell. An environment variable set on a cloud environment is a different
thing, and the steps below say when it is the right one.
