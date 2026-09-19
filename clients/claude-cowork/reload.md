The hooks run here, so the session start hook has already printed. Run it again
with the script the plugin carries:

    find ~ -name {{session-start}} 2>/dev/null

    printf '{}' | <the path it finds>
