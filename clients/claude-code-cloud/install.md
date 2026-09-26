A cloud session resolves no marketplace, so the marketplace install does not work. There are two ways to install it there. An agent asks which of the two you want before doing anything:

### Every session

1. Open 🔗 [claude.ai/code](https://claude.ai/code), open the environment settings, and find the Setup script field. See 🔗 [docs](https://code.claude.com/docs/en/cloud-environments#setup-scripts).
2. Paste the "Cloud Session Install Script" (see below) into that field and save. The field is yours to edit, so an agent prints the steps and the script for you rather than pasting them itself.
3. Start a new session. The environment rebuilds and runs the script before the session begins.

### This session only

1. Set your permission mode to accept edits, or the auto-permissions classifier refuses the write.
2. Ask the agent to run the "Cloud Session Install Script" (see below).
3. The hooks take effect from your next message. Session start has passed, so ask the agent to run the session start hook against this one:

        printf '{}' | {{root}}/hooks/{{session-start}}

4. The skills are on disk as soon as the script finishes, and an agent follows one by reading it at `{{root}}/skills/<name>/SKILL.md`. Nothing waits on the menu.
5. Run `/reload-skills` when you want them listed in the menu, as `/{{name}}-settings`, `/{{name}}-update` and the rest. Each skill carries the plugin's name, so a second plugin built the same way never overwrites it. `/reload-plugins` does not work over a remote connection, and this install method adds no plugin.

The container takes all of it away when the session ends.

### Cloud Session Install Script

Paste this once.

```bash
#!/bin/bash
if git clone --depth 1 https://github.com/{{repository}} /opt/{{name}}.new; then
	rm -rf /opt/{{name}}
	mv /opt/{{name}}.new /opt/{{name}}
else
	echo "{{name}}: the clone failed, keeping whatever was already there" >&2
	rm -rf /opt/{{name}}.new
fi
{{root}}/install.sh || true
```
