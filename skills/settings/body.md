---
name: settings
description: Change {{name}}'s settings
---

# {{name}} settings

Settings are stored in `{{home}}/settings` with one `key = value` a line.
Blank lines and lines opening with `#` are ignored, and the last assignment of a key is the one that counts.

{{settings-table}}

`{{prefix}}_HOME` moves the settings file and the state under it together.

## Before writing anything

Read the steps below. Where they say no hook runs, write no
file: follow them instead, since nothing would read what you wrote.

## How to update settings

Refuse a value the table above does not allow, saying what it takes and writing
nothing; where the file already holds one, say so, since the hooks read it as
the default.

If the file is not there, create and add the setting.
Else, read the file, replace or add the setting, and write it back.
Leave the rest of the file as it is, comments included.

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
