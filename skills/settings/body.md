---
name: settings
description: Change {{name}}'s settings
---

# {{name}} settings

Settings are stored in `{{home}}/settings` with one `key = value` a line.
Blank lines and lines opening with `#` are ignored, and the last assignment of a key is the one that counts.

{{settings-table}}

`{{prefix}}_HOME` moves the settings file and the state under it together.

A project can hold settings of its own in `.{{name}}/settings` at its root, in
the same shape. The hooks read it before `{{home}}/settings`, and an
environment variable before either. Write there when the user wants a value
for everyone working in the project rather than for themselves, and say that
it is a file to commit.

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
