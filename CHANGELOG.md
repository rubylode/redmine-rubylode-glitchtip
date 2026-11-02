# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-11-01

### Added

- A "Show the block on" section in the settings: the welcome page (left or right column), the project Overview page (left or
  right), My page, any page whose path matches a pattern (one per line, `*` wildcard, query string and trailing slash
  ignored, settings, administration and sign-in pages never matched unless named), and the top menu. Every placement uses the
  same partial, so it honours "Who may see it" and the cache.
- A compact variant of the block for the path patterns, and a `compact` and an `inline_stylesheet` local on the partial.
- Path patterns are checked before saving: they must start with `/`, carry no scheme, host or spaces, and stay short.
- A "How to show the block on other pages" help on the settings page and in the README: macro snippets for wiki pages, news,
  issues and the welcome text (Redmine draws it with its text formatter, so macros work there), the My page block, the path
  list, the partial for themes and plugins, the standalone page and the top menu, with a place, how and setting table.
- An optional link to `/glitchtip_errors` in the top menu.

## [0.1.0] - 2026-11-01

### Added

- The recent GlitchTip errors that need attention (unresolved, seen within the look-back window, of the chosen levels, at or
  above the minimum event count, in the project allow-list), ordered by level, event count and last seen, with a summary.
- A `{{glitchtip_errors}}` wiki macro, a page at `/glitchtip_errors`, a My page block and a reusable partial.
- Settings for the address, organization, token variable name, look-back hours, minimum events, levels, maximum rows,
  project allow-list, cache, failure cache, timeout, block title and who may see it, checked before they are saved.
- A "Status unavailable" fallback with the page still rendering, and an administrators-only hint while not configured.
- The API token is read from an environment variable named `GLITCHTIP_*`, sent only to the saved host over https (plain http
  for loopback or when allowed), never follows a redirect, and is never saved, shown or logged.
- A throwaway demo Redmine on port 3014 with a fake GlitchTip, and a Playwright script for the screenshots.
