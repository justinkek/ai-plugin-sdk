    printf '{}' | "$(codex plugin list | sed -n 's/.*\(\/.*{{name}}\/[0-9.]*\).*/\1/p' | head -1)/hooks/{{session-start}}"

If that prints nothing, take the plugin root from the line
`Installed plugin root:` that the install printed, and run the script inside its
`hooks` directory.
