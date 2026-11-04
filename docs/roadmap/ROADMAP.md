# Roadmap

## Goal

Show the GlitchTip errors that may need attention inside Redmine: unresolved issues seen again within the last N hours, by project, with count, level, last seen and a link to the issue in GlitchTip. Read-only.

## Decisions

- One settings form, the token only in an environment variable, a wiki macro, a page, a My page block, a partial and a block on the Status page of Rubylode Status. The answer is cached, with a shorter cache after a failure, and a failure shows "Status unavailable" instead of an error page.
- An issue needs attention when it is unresolved, not ignored and last seen in the window. The plugin filters after fetching, so it does not depend on how GlitchTip reads `start`, `end` or a search query. The event count is the issue's total.
- The plugin builds the issue link as `{address}/{organization}/issues/{id}`. GlitchTip documents its `permalink` field with the default "Not implemented", so it is not used.
- The token's variable name must start with `GLITCHTIP_`. The token goes only to the saved host, over https unless the host is loopback or http is explicitly allowed. Redirects are never followed.
- Theming is done with `--rubylode-glitchtip-*` custom properties.

## Open

- Check the "issues" link shape and the `Link` header paging against a running GlitchTip. Only its published API description was available while building.
- Filter by project id in the request instead of after fetching, for organizations with very many projects.
- Per-project visibility: show only the projects a Redmine user belongs to.
- An optional count of events inside the window, if GlitchTip exposes it cheaply.
