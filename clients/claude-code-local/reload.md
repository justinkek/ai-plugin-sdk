The hook registers the script as `${CLAUDE_PLUGIN_ROOT}/hooks/{{session-start}}`, and
a shell cannot read that variable, so find the file and run it:

    find ~ -name {{session-start}} 2>/dev/null

    printf '{}' | <the path it finds>
