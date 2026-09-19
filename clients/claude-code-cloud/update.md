Installed by the Cloud Session Install Script from
🔗 [the install instructions](INSTALL.md), where the checkout lives at
`/opt/{{name}}` inside the container.

For every session, edit anything in the Setup script field of your cloud
environment. The edit rebuilds the environment, which runs the script again and
pulls the latest release. An untouched environment rebuilds about weekly on its
own, so it follows releases either way.

For the current session, run `/{{name}}-update`, or ask the agent to
update {{name}}.

(audience: agents) Run the refresh script. Pulling the checkout on its own is not an update.

    printf '{}' | {{root}}/refresh.sh

(audience: agents) Then run the session start hook again, since the copy in the
menu is the one loaded before the update:

    printf '{}' | {{root}}/hooks/{{session-start}}

Run `/reload-skills` when you want the menu to list the new copy. The skills on
disk are already the new ones, and an agent reads them there.
