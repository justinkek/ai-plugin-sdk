    printf '{}' | {{root}}/hooks/{{session-start}}

The container is rebuilt for every session, so a setting written to the file
lasts as long as this session does. To keep one, set a `{{prefix}}_`
environment variable on the cloud environment, see
[the docs](https://code.claude.com/docs/en/cloud-environments#set-environment-variables).
