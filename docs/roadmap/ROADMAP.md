# Roadmap

## Goal

Show the GlitchTip errors that may need attention inside Redmine: unresolved issues seen again within the last N hours, by
project, with count, level, last seen and a link to the issue in GlitchTip. Open source, configurable, read-only.

## Decisions

- **Same design as the Uptime Kuma plugin**: one settings form, token only in an environment variable, a wiki macro, a page, a
  My page block, a partial, a cached answer with a shorter failure cache, and "Status unavailable" instead of an error page.
- **The rule is "unresolved, not ignored, last seen in the window"**, filtered on our side after fetching, so it does not
  depend on how GlitchTip interprets `start`, `end` or a search query. The event count is the issue's total.
- **The issue link is built by the plugin**: `{address}/{organization}/issues/{id}`. GlitchTip's `permalink` field is
  documented with the default "Not implemented", so it is not used.
- **The token's variable name must start with `GLITCHTIP_`**, the token goes only to the saved host, over https unless
  loopback or explicitly allowed, and redirects are never followed.
- **Theming** with `--rubylode-glitchtip-*` custom properties.

## Open

- Check the "issues" link shape and the `Link` header paging against a running GlitchTip (only its published API
  description was available while building).
- Filter by project id in the request instead of on our side, for organizations with very many projects.
- Per-project visibility (show only the projects a Redmine user belongs to).
- An optional count of events inside the window, if GlitchTip exposes it cheaply.
