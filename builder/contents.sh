#!/usr/bin/env bash

# build sources this file after builder/manifest.sh, so what that sets is
# already here. shellcheck reads one file at a time and cannot see it.
# shellcheck disable=SC2154

# What an install copies out of a distribution folder: the hooks and the
# libraries beside them, whatever else the plugin ships, the skills, and the
# commands.

# One case arm per setting, so a hook reads a default, a kind or a list of
# allowed values without jq.
case_function() {
  local named="$1" filter="$2"
  printf '%s() {\n  case "$1" in\n' "$named"
  settings_json | jq --raw-output "$filter" \
    | sed 's/printf %s/printf '"'"'%s'"'"'/'
  printf '  esac\n}\n'
}

# What the libraries read in place of knowing a plugin. Written into every
# distribution, so a hook needs no jq to read a setting.
plugin_manifest_sh() {
  printf '#!/usr/bin/env bash\n\n'
  printf '# The plugin these libraries were built for. Nothing else here names it.\n\n'
  printf "PLUGIN_NAME='%s'\n" "$name"
  printf "PLUGIN_PREFIX='%s'\n" "$prefix"
  printf "PLUGIN_DISPLAY_NAME='%s'\n\n" "$display"

  case_function plugin_setting_default \
    'to_entries[] | "    \(.key)) printf %s \(.value.default // "" | @sh) ;;"'
  printf '\n'
  case_function plugin_setting_kind \
    'to_entries[] | "    \(.key)) printf %s \(.value.kind // "text" | @sh) ;;"'
  printf '\n'
  case_function plugin_setting_values \
    'to_entries[] | select(.value.values) | "    \(.key)) printf %s \((.value.values | join(" ")) | @sh) ;;"'

  # What this plugin prints at the start of a session, for the SDK's own hook
  # that prints it again on a client that never carried it.
  printf '\nplugin_session_start_hooks() {\n'
  jq --raw-output $'.hooks.SessionStart[]? | "  printf \'%s\\\\n\' " + (. | @sh)' "$manifest"
  printf '}\n'
}

# A generated file says so on its second line, so a reader who opens one knows
# before they edit it.
mark_scripts() {
  local folder="$1" script
  for script in "$folder"/*.sh "$folder"/hooks/*.sh "$folder"/hooks/lib/*.sh \
    "$folder"/hooks/lib/*/*.sh; do
    [ -f "$script" ] || continue
    sed -i.bak "1a\\
# $generated" "$script"
    rm -f "$script.bak"
  done
}

hooks() {
  local target="$1" helper
  mkdir -p "$target/hooks/lib"
  cp "$plugin"/hooks/*.sh "$target/hooks/" 2>/dev/null || true
  # The SDK's own hooks, which a plugin does not write and does not register.
  if has_session_start; then cp "$sdk"/hooks/*.sh "$target/hooks/"; fi
  # lib/ is a directory per subject with one function to a file, so it is copied
  # whole. settings.json is the build's, not a hook's.
  cp -R "$sdk"/lib/. "$target/hooks/lib/"
  rm -f "$target/hooks/lib/settings.json"
  plugin_manifest_sh > "$target/hooks/lib/plugin-manifest.sh"

  # A plugin's own hooks/ holds hooks, which a harness runs, and files its hooks
  # source, which nothing runs. The second kind ends -lib.sh, and migrations.sh
  # is one of them by another name. They go beside the SDK's libraries, so what
  # is left in hooks/ is what the manifest registers and nothing else.
  for helper in "$target"/hooks/*-lib.sh "$target/hooks/migrations.sh"; do
    [ -f "$helper" ] || continue
    mv "$helper" "$target/hooks/lib/$(basename "$helper")"
  done
}

# Whatever else the plugin says it ships: its rules, its templates, its data.
shipped() {
  local target="$1" folder
  for folder in $(jq --raw-output '.ships[]? // empty' "$manifest"); do
    [ -d "$plugin/$folder" ] || continue
    mkdir -p "$target/$folder"
    cp -R "$plugin/$folder/." "$target/$folder/"
  done
}

commands() {
  local target="$1" source
  mkdir -p "$target/commands"
  for source in "$sdk"/commands/*.md; do
    filled < "$source" > "$target/commands/$(basename "$source")"
  done
}

contents() {
  local harness="$1" target="$2"
  mkdir -p "$target"
  cp "$manifest" "$target/plugin.json"

  if ships "$harness" hooks; then hooks "$target"; fi
  shipped "$target"
  if ships "$harness" skills; then skills "$harness" "$target"; fi
  if ships "$harness" commands; then commands "$target"; fi
}
