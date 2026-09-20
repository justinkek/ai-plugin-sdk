The hooks read the file every time they run, so a change takes effect at once,
and the reload skill prints with the new value.

The file is written inside the container, which is rebuilt for every session, so
a setting you want to keep goes in a `{{prefix}}_` environment variable on
the cloud environment, see
[the docs](https://code.claude.com/docs/en/cloud-environments#set-environment-variables).
