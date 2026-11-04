# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.1] - 2026-11-04

### Changed

- Needs Redmine 5.1 or newer instead of 5.0. Redmine 5.0 cannot be tested in CI (the sqlite3 gem it pins does not build
  there), and this plugin only claims what CI verifies. No code changed.

## [1.1.0] - 2026-11-04

### Changed

- Runs on Redmine 5.0 and newer. The plugin's own tests pass unchanged on those versions; no code changed.

## [1.0.1] - 2026-11-03

### Added

- Show a Rubylode thumbnail at the top of the README.

### Changed

- Make the README plainer and add a licence section.
- Word the changelog entries more plainly.
- Write the checksum file inside the build step of the release job.

## [1.0.0] - 2026-11-02

First stable release.

### Changed

- Show the project address on Administration, Plugins.
- Set the name, author and version to match the listing on redmine.org.

## [0.2.1] - 2026-11-02

### Fixed

- Log a warning instead of failing the page when the cache cannot be read or written (for example a cache file owned by another user). The block is built from a live fetch, or shows "Status unavailable".

## [0.2.0] - 2026-11-01

### Added

- A "Show the block on" section in the settings: the welcome page (left or right column), the project Overview page (left or right), My page, pages whose path matches a pattern, and the top menu.
- Path patterns: one per line, `*` as a wildcard. The query string and a trailing slash are ignored. Settings, administration and sign-in pages never match unless a pattern names them.
- A compact variant of the block for the path patterns, and `compact` and `inline_stylesheet` locals on the partial.
- Validation of path patterns on save: they must start with `/`, have no scheme, host or spaces, and stay short.
- Help on the settings page and in the README: a place, how and setting table, with snippets for the macro, the My page block, the path list, the partial, the page and the top menu.
- A top menu link to `/glitchtip_errors`.

Every placement uses the same partial, so each honours "Who may see it" and the cache.

## [0.1.0] - 2026-11-01

### Added

- The recent GlitchTip errors that need attention: unresolved, seen within the look-back window, of the chosen levels, at or above the minimum event count and in the project allow-list. They are ordered by level, event count and last seen, under a summary line.
- A `{{glitchtip_errors}}` wiki macro, a page at `/glitchtip_errors`, a My page block and a reusable partial.
- Settings for the address, organization, token variable name, look-back hours, minimum events, levels, maximum rows, project allow-list, cache, failure cache, timeout, block title and who may see it. They are checked before they are saved.
- A "Status unavailable" fallback that leaves the rest of the page rendering, and a hint for administrators while the plugin is not configured.
- The API token comes from an environment variable named `GLITCHTIP_*`. It goes only to the saved host over https (plain http for loopback or when allowed), is never sent along a redirect, and is never saved, shown or logged.
- A throwaway demo Redmine on port 3014 with a fake GlitchTip, and a Playwright script for the screenshots.
