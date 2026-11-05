# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.1.0] - 2026-11-05

No change to what the plugin does. This release carries the documentation and the build.

### Changed

- The screenshots in the README are retaken for 2.0.0: the new labels, the new page path and the Status notice.
- The workflows use the current versions of the GitHub actions, and Dependabot sends one grouped update a month instead of one pull request per action.

## [2.0.0] - 2026-11-04

Rubylode GlitchTip 2.0.0 follows the Rubylode plugin standard. Read "Upgrading" before you update.

### Added

- A block on the Status page of Rubylode Status, when that plugin is installed. The state is ok, warning (some errors need a look), down (GlitchTip does not answer) or unknown (not set up).
- A notice on the settings page and on the plugin's page that says whether Rubylode Status is installed.
- A migration that moves saved settings to the new names, and a reverse migration that moves them back.
- A visible "Column" label next to each column select.
- A "Pages matching these paths" check box. Paths only draw the block while it is checked.

### Changed

- The plugin's page is `/status/glitchtip`. `/glitchtip_errors` redirects there for this release.
- The macro is `{{glitchtip_status}}`. `{{glitchtip_errors}}` still works for this release.
- The partial is `rubylode_glitchtip/status` and the My page block is `rubylode_glitchtip_status`. The old partial `rubylode_glitchtip/errors` and the old block `rubylode_glitchtip_errors` still work for this release, so saved My page layouts keep drawing the block.
- The default block title is "Errors" (was "Errors needing attention"). The top menu caption is the block title.
- Settings are renamed: `lookback_hours` is `look_back_hours`; `path_patterns` is `matching_page_paths`, with `show_on_matching_pages` on when there were paths.
- A `*` in a path stands for anything inside one path segment, and `**` for anything including slashes. Saved patterns keep their meaning because each `*` became `**` in the migration.
- Labels and hints follow the standard: "GlitchTip address", "Token variable", "Allowed hosts" (was "Extra hosts for the token"), "Allow plain http" (was "Allow plain http (internal network)"), "Look-back hours". The token variable hint now says the name must start with `GLITCHTIP_`, and the timeout has a hint.
- The settings are read through `RubylodeGlitchtip::Settings` (was `RedmineRubylodeGlitchtip::Defaults` and `RubylodeGlitchtip::Configuration`). The locale keys live under `rubylode_glitchtip.settings.<key>.label` and `.hint`.
- The top menu item is hidden, and so is the "Show in the top menu" setting, while Rubylode Status is installed.
- Check boxes are worded "Check", not "Tick". Spelling is en-US.

### Removed

- The old My page gate. In 1.x "My page" switched the block off on every My page when unticked. It now adds the block to the default My page, for people who have not arranged their own. The migration turns the old setting, on or off, into off, so nobody sees a change; blocks people added themselves keep working. Check "My page" if you want the block on the default My page.

### Upgrading

1. Run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`. It moves your saved settings to the new names.
2. Change links and bookmarks from `/glitchtip_errors` to `/status/glitchtip`, and the macro from `glitchtip_errors` to `glitchtip_status`. The old ones work in 2.x and are removed in the next major release.
3. A block title you set yourself stays. A saved title of "Errors needing attention" becomes "Errors".
4. Anything of yours that reads `RedmineRubylodeGlitchtip::Defaults` or `RubylodeGlitchtip::Configuration` must read `RubylodeGlitchtip::Settings`.

To go back to 1.x, run `bundle exec rake redmine:plugins:migrate NAME=redmine_rubylode_glitchtip VERSION=0`, which restores the 1.x setting names, then install 1.1.1.

## [Unreleased]

## [1.1.1] - 2026-11-04

### Changed

- Require Redmine 5.1 or newer instead of 5.0. Redmine 5.0 cannot be tested in CI (the sqlite3 gem it pins does not build
  there), and this plugin only claims what CI verifies. No code changed.

## [1.1.0] - 2026-11-04

### Changed

- Run on Redmine 5.0 and newer. The plugin's own tests pass unchanged on those versions; no code changed.

## [1.0.1] - 2026-11-03

### Added

- Show a Rubylode thumbnail at the top of the README.

### Changed

- Make the README plainer and add a license section.
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
- Help on the settings page and in the README: a table of where, how and which setting, with snippets for the macro, the My page block, the path list, the partial, the page and the top menu.
- A top menu link to `/glitchtip_errors`.

Every placement uses the same partial, so each follows "Who may see the block" and shares the cache.

## [0.1.0] - 2026-11-01

### Added

- The recent GlitchTip errors that need attention: unresolved, seen within the look-back window, of the chosen levels, at or above the minimum event count and in the project allow-list. They are ordered by level, event count and last seen, under a summary line.
- A `{{glitchtip_errors}}` wiki macro, a page at `/glitchtip_errors`, a My page block and a reusable partial.
- Settings for the address, organization, token variable name, look-back hours, minimum events, levels, maximum rows, project allow-list, cache, failure cache, timeout, block title and who may see it. They are checked before they are saved.
- A "Status unavailable" fallback that leaves the rest of the page rendering, and a hint for administrators while the plugin is not configured.
- The API token comes from an environment variable named `GLITCHTIP_*`. It goes only to the saved host over https (plain http for loopback or when allowed), is never sent along a redirect, and is never saved, shown or logged.
- A throwaway demo Redmine on port 3014 with a fake GlitchTip, and a Playwright script for the screenshots.

[Unreleased]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v1.1.1...HEAD
[2.1.0]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v1.1.1...v2.0.0
[1.1.1]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v0.2.1...v1.0.0
[0.2.1]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/rubylode/redmine-rubylode-glitchtip/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rubylode/redmine-rubylode-glitchtip/releases/tag/v0.1.0
