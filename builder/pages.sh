#!/usr/bin/env bash

# build sources this file after builder/manifest.sh, so what that sets is
# already here. shellcheck reads one file at a time and cannot see it.
# shellcheck disable=SC2154

# Every page a person reads: one client's steps, a README per distribution, and
# the install page on the repository.

# A page is the plugin's where it has one, and the SDK's otherwise, so a plugin
# overrides one client's steps without carrying the other six.
page_source() {
  local named="$1" client="$2" where
  for where in "$plugin/clients/$client/$named.md" "$sdk/clients/$client/$named.md"; do
    if [ -s "$where" ]; then printf '%s' "$where"; return 0; fi
  done
  return 1
}

client_source() {
  local client="$1" where
  for where in "$plugin/clients/$client/client.json" "$sdk/clients/$client/client.json"; do
    if [ -f "$where" ]; then printf '%s' "$where"; return 0; fi
  done
  return 1
}

# A folder says what it is; a harness says which clients it can install for.
named_client() { jq --raw-output '.name' "$(client_source "$1")"; }

# One page of one client, with its links published. A page holding
# {same as <client>} is that client's page, read in its place.
page() {
  local named="$1" client="$2" source pointed
  source="$(page_source "$named" "$client")" || return 0
  pointed="$(sed -n "1s/^{same as \\([a-z-]*\\)}$/\\1/p" "$source")"
  if [ -n "$pointed" ]; then
    source="$(page_source "$named" "$pointed")" || {
      printf 'clients/%s/%s.md points at %s, which has no such page\n' "$client" "$named" "$pointed" >&2
      exit 1
    }
    if sed -n '1p' "$source" | grep --quiet '^{same as '; then
      printf 'clients/%s/%s.md points at %s, which points on again\n' "$client" "$named" "$pointed" >&2
      exit 1
    fi
  fi

  sed -E "s@\]\(([A-Za-z-]+\.md)([^)]*)\)@](PUBLISHED/\1\2)@g" "$source" \
    | sed "s@PUBLISHED@$published@g" | filled
}

# Whether this install serves one client or several is the only branch in here,
# and both readers of it ask the same way.
serves_one() { [ "$(served "$1" | wc -l)" = "1" ]; }

# The steps for an install: one client's page, or one per client with the
# signature that tells them apart.
branched() {
  local named="$1" harness="$2" client
  if serves_one "$harness"; then
    page "$named" "$(served "$harness")"
    return 0
  fi

  printf 'One install serves several clients. Read the signatures, then follow the\n'
  printf 'steps under the one that matches.\n'
  for client in $(served "$harness"); do
    printf '\n### %s\n\n' "$(named_client "$client")"
    page signature "$client"
    printf '\n'
    page "$named" "$client"
  done
}

# One section of a README: one client's page, or one per client under its name.
section() {
  local named="$1" heading="$2" harness="$3" client shown="" first=1
  for client in $(served "$harness"); do
    if page_source "$named" "$client" >/dev/null; then shown="$shown $client"; fi
  done
  if [ -z "$shown" ]; then return 0; fi

  printf '## %s\n\n' "$heading"
  if serves_one "$harness"; then
    page "$named" "${shown# }"
  else
    for client in $shown; do
      if [ "$first" = "0" ]; then printf '\n'; fi
      first=0
      printf '### %s\n\n' "$(named_client "$client")"
      page "$named" "$client"
    done
  fi
  printf '\n'
}

# One page for one client, so a reader who fetches it gets that client's steps
# and no other's.
client_page() {
  local client="$1" target="$2" out="$2/clients/$1.md"
  mkdir -p "$target/clients"
  {
    printf '# %s for %s\n\n(audience: humans)\n\n' "$name" "$(named_client "$client")"
    if page_source support "$client" >/dev/null; then
      printf '## What works\n\n'
      page support "$client"
      printf '\n'
    fi
    printf '## Installing\n\n'
    page install "$client"
    printf '\n## Updating\n\n'
    page update "$client"
    printf '\n## Uninstalling\n\n'
    page uninstall "$client"
    printf '\n## Note\n\n%s\n' "$generated"
  } > "$out"
}

readme() {
  local harness="$1" target="$2" body client
  body="$({
    printf '# %s for %s\n\n(audience: humans)\n\n' "$name" "$(named_harness "$harness")"
    section support "What works" "$harness"
    section install "Installing" "$harness"
    section update "Updating" "$harness"
    section uninstall "Uninstalling" "$harness"
    printf '## Note\n\n%s\n' "$generated"
  })"
  printf '%s\n' "$body" > "$target/README.md"

  for client in $(served "$harness"); do
    client_page "$client" "$target"
  done
}

# The install page a person reads on the repository, from the same sources.
install_page() {
  local harness client
  use_harness_root ""
  {
    if [ -f "$plugin/install-page/intro.md" ]; then filled < "$plugin/install-page/intro.md"; fi
    printf '\nOpen the page for your client and follow it. Each one carries that client\n'
    printf 'and no other, and the folder it sits in is what the install copies:\n\n'
    printf '| Client | Page |\n| --- | --- |\n'
    for harness in $(harnesses); do
      if builds_for "$harness"; then
        for client in $(served "$harness"); do
          printf '| %s | [distributions/%s/clients/%s.md](distributions/%s/clients/%s.md) |\n' \
            "$(named_client "$client")" "$harness" "$client" "$harness" "$client"
        done
      fi
    done
    printf '\n'
    if [ -f "$plugin/install-page/tail.md" ]; then filled < "$plugin/install-page/tail.md"; fi
    # The one place that records which SDK wrote the committed folders.
    printf '\n## Note\n\n%s\nBuilt with ai-plugin-sdk %s.\n' "$generated" "$sdk_version"
  } > "$page"
}
