Skills under `/mnt/skills/plugins/`, no plugin directory, and no
`{{home}}` written by anything but you. No hook runs, so nothing
reads a settings file, and what a session start hook would print only arrives
when the reload skill prints it.
