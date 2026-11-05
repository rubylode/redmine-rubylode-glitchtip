# Rubylode GlitchTip for Redmine

<p><img src="docs/thumbnail.png" alt="Rubylode GlitchTip plugin" width="160"></p>

[![tests](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-glitchtip/tests.yml?branch=main&label=tests)](https://github.com/rubylode/redmine-rubylode-glitchtip/actions/workflows/tests.yml)
[![security](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-glitchtip/security.yml?branch=main&label=security)](https://github.com/rubylode/redmine-rubylode-glitchtip/actions/workflows/security.yml)
[![version](https://img.shields.io/github/v/tag/rubylode/redmine-rubylode-glitchtip?sort=semver&label=version)](https://github.com/rubylode/redmine-rubylode-glitchtip/tags)
[![license](https://img.shields.io/github/license/rubylode/redmine-rubylode-glitchtip)](https://github.com/rubylode/redmine-rubylode-glitchtip/blob/main/LICENSE)
![Redmine](https://img.shields.io/badge/Redmine-5.1%20%7C%206.0%20%7C%206.1%20%7C%207.0-b22222)
![Ruby](https://img.shields.io/badge/Ruby-3.2%20%7C%203.3%20%7C%203.4%20%7C%204.0-cc342d)

TL;DR: this plugin shows the recent [GlitchTip](https://glitchtip.com) errors that may need attention inside
[Redmine](https://www.redmine.org), as a wiki macro, a page, a My page block, a partial and a block on the Status page.

Each shows a summary line and a table with the project, level, event count, last seen and a link to the issue in GlitchTip.
The token stays in an environment variable and the block only reads.

Status: version 2.1.0, needs Redmine 5.1 or newer. Upgrading from 1.x? Read the [changelog](CHANGELOG.md) first: settings were
renamed and the page moved. `docs/roadmap/ROADMAP.md` lists what is decided and what is still open.

Contents:

- [What it does](#what-it-does)
- [What needs attention](#what-needs-attention)
- [Install](#install)
- [Settings](#settings)
- [Where it shows](#where-it-shows)
- [Security](#security)
- [Theming](#theming)
- [Try it](#try-it)
- [Troubleshooting](#troubleshooting)
- [Tests](#tests)
- [Releasing](#releasing)
- [License](#license)

## What it does

A summary line ("No errors need attention", or "3 issues need attention, 214 events") and, under it, a table of the issues:
title and culprit, project, level, event count and when it was last seen. The title links to the issue in GlitchTip.

![The plugin's page at /status/glitchtip, titled Errors, with five issues (the fatal one first) and the Status plugin notice](docs/screenshots/errors-page.png)

Ways to show it ([Where it shows](#where-it-shows) has the details):

- A wiki macro: `{{glitchtip_status}}`, or `{{glitchtip_status(title=Production errors)}}`.

  ![The macro on a wiki page](docs/screenshots/wiki-macro.png)

- A page at `/status/glitchtip`.
- A My page block called "Errors" (`rubylode_glitchtip_status`), added from the My page's block list.
- A partial other plugins and views can render: `render partial: "rubylode_glitchtip/status"`, with the optional locals
  `title` and `show_title`.
- A block on the Status page of [Rubylode Status](https://github.com/rubylode/redmine-rubylode-status), when that is installed.

When nothing needs attention the summary says so and there is no table:

![No errors need attention](docs/screenshots/errors-none.png)

When GlitchTip cannot be asked (no answer, a wrong token, a server error) the block says "Status unavailable" and the page
around it still renders. Administrators also see why. Until the address and the organization are set, administrators get a
hint with a link to the settings and everyone else sees nothing.

![Status unavailable, with the reason for an administrator](docs/screenshots/errors-unavailable.png)

Everything GlitchTip supplies (titles, culprits, project names) is escaped, so an error whose title contains markup shows as
text. Links are built from the saved address, the organization slug and the issue's numeric id.

## What needs attention

An issue needs attention when all of these hold:

- it is unresolved (resolved and ignored issues never show),
- it was last seen within the look-back window (24 hours by default). A new issue and an old one that came back both
  count, because the window looks at the last time it was seen,
- its level is one of the chosen levels (error and fatal by default),
- its event count is at least the minimum (1 by default). The count is the issue's total, as GlitchTip reports it, not
  the number of events inside the window, and
- it belongs to one of the projects in the allow-list, when there is one.

The issues are ordered by level (fatal, error, warning, info, debug), then by event count (most first), then by last seen
(newest first). Up to "Maximum rows" are shown; the summary still counts all of them ("and 4 more issues" is shown under the
table).

The rule is one small class, `RubylodeGlitchtip::AttentionRule`, with its own unit tests.

## Install

Redmine 5.1 or newer.

1. Put the plugin folder in Redmine's `plugins/` directory, named `redmine_rubylode_glitchtip`.
2. Run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`.
3. If the plugin reads an environment variable, set it where Redmine runs, then restart Redmine.
4. In Administration, Plugins, open the plugin and choose Configure.

The plugin reads an environment variable: create an API token in GlitchTip (Profile, Auth Tokens) with read access to
issues and put it in a variable that starts with `GLITCHTIP_`, for example `GLITCHTIP_API_TOKEN`, before Redmine starts. Then
set the GlitchTip address and the organization slug in the settings.

To get the folder, clone it: `git clone https://github.com/rubylode/redmine-rubylode-glitchtip.git redmine_rubylode_glitchtip`.
To remove the plugin, run `bundle exec rake redmine:plugins:migrate NAME=redmine_rubylode_glitchtip VERSION=0 RAILS_ENV=production`,
delete the folder and restart. The settings are one row in the settings table.

Upgrading from 1.x: step 2 moves your saved settings to the new names. The changelog lists what changed.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| GlitchTip address | empty | For example `https://glitchtip.example.com`. Empty means the block is shown to administrators only, with a hint. |
| Organization slug | empty | The organization's short name: the first part of the path in GlitchTip's address. |
| Token variable | `GLITCHTIP_API_TOKEN` | The name of the variable holding the token, not the token. Must start with `GLITCHTIP_`. |
| Allowed hosts | empty | Hosts that may receive the token besides the address above, separated by spaces or commas. |
| Allow plain http | off | See [Security](#security). |
| Look-back hours | 24 | An issue needs attention when it was seen again within this many hours. |
| Minimum event count | 1 | Issues with fewer events in total are left out. |
| Levels to include | error, fatal | Any of fatal, error, warning, info, debug. |
| Maximum rows | 10 | From 1 to 100. |
| Projects | empty | Optional GlitchTip project slugs; empty means all projects. |
| Cache seconds | 60 | GlitchTip is asked at most once in this many seconds. |
| Failure cache seconds | 30 | After a failed answer GlitchTip is left alone for this many seconds. |
| Timeout seconds | 2 | A request to GlitchTip is given up after this many seconds. |
| Block title | Errors | The heading of the block and the name of the top menu link. |
| Who may see the block | Everyone who is signed in | Or administrators only. |
| Welcome page | off | Adds the block to Redmine's home page, in the left or the right column. |
| My page | off | Adds the block to the default My page, for people who have not arranged their own. |
| Project Overview page | off | Adds the block to every project's Overview page, left or right. |
| Pages matching these paths | off | Adds a small version of the block to each page whose path matches one of the paths. |
| Paths | empty | One path per line, starting with `/`. |
| Show in the top menu | off | Adds a link to `/status/glitchtip` to the top menu. Hidden while Rubylode Status is installed. |

![The Show the block on section of the settings](docs/screenshots/settings.png)

![The help on the settings page](docs/screenshots/settings-help.png)

The form checks the values before saving and shows what is wrong; nothing is saved until they are right.

## Where it shows

The block is one partial, so every place below shows the same block, to the same people (the setting "Who may see the block"),
from the same cached answer: GlitchTip is asked once for all of them. The same help is on the plugin's settings page.

### Status page

With [Rubylode Status](https://github.com/rubylode/redmine-rubylode-status) installed, the block is on its Status page and
the plugin drops its own top menu item. The plugin's own page, `/status/glitchtip`, is there with or without it. The Status
plugin gets the state (no errors, some need a look, GlitchTip not answering, or not set up), a one-line summary and the list of issues.

### In text

Type the macro in a wiki page, a news item, an issue description or comment, a forum message, the project
description, or the welcome text (Administration, Settings, General). The welcome text is drawn with Redmine's text
formatter, so a macro in it works like one in a wiki page.

    {{glitchtip_status}}
    {{glitchtip_status(title=Production errors)}}

The macro was called `glitchtip_errors` before 2.0.0. The old name still works in 2.x.

### On My page

Open My page, Personalize this page, choose "Errors" in the block list and Add. Each person adds it for themselves, whatever
the setting says. Check "My page" in the settings to add it to the default My page, which people get until they arrange their own.

### On the welcome page and every project's Overview

Check "Welcome page" or "Project Overview page" in the settings and choose the left or the right column. They use
Redmine's own hooks (`view_welcome_index_left`/`_right`, `view_projects_show_left`/`_right`).

![The welcome page with the block in the right column](docs/screenshots/welcome-page.png)

### At the end of chosen pages

Check "Pages matching these paths" and list the paths in "Paths", one per line. The compact block (no project column, no
culprit) is drawn after the page's content:

    /issues
    /projects/*/issues
    /projects/*/wiki/**

![The compact block at the end of the issues list](docs/screenshots/compact-on-issues.png)

A `*` stands for anything inside one path segment and `**` for anything, slashes included. The query string and a trailing slash are ignored (`/issues` matches
`/issues?set_filter=1` and `/issues/`). Settings, administration, sign-in and account pages never match, not even `/*`,
unless a path starts with their own path (`/admin/**`). The block's own page never matches. Only plain page views get it,
not form posts or AJAX requests. The form refuses a path that does not start with `/`, has a scheme or host, spaces, or is
longer than 200 characters, and more than 20 paths.

### In a theme or another plugin

Render the partial. Optional locals:

- `title`: a heading of its own
- `show_title`: `false` hides the heading
- `compact`: `true` for the smaller block
- `inline_stylesheet`: `true` when the page has already sent its head, so the partial carries its own stylesheet link

```erb
<%= render partial: "rubylode_glitchtip/status" %>
<%= render partial: "rubylode_glitchtip/status", locals: { title: "Production errors", compact: true } %>
```

The partial was called `rubylode_glitchtip/errors` before 2.0.0. The old name still works in 2.x.

### As a page, and in the top menu

The page is `/status/glitchtip`. Check "Show in the top menu" for a link to it, named like the block title. The old page,
`/glitchtip_errors`, redirects there in 2.x.

### All the places

| Place | How | Needs a setting |
|---|---|---|
| Wiki pages, news, issues, forums, project description | `{{glitchtip_status}}` | No |
| Welcome text | `{{glitchtip_status}}` in Administration, Settings, General | No |
| My page | Personalize this page, then Add | No ("My page" adds it to the default My page) |
| Welcome page | Check "Welcome page" | Welcome page |
| Project Overview page | Check "Project Overview page" | Project Overview page |
| Any other page | Check "Pages matching these paths" and list the path, such as `/issues` | Pages matching these paths |
| A theme or another plugin | `render partial: "rubylode_glitchtip/status"` | No |
| Its own page | Open `/status/glitchtip` | No |
| Top menu | Check "Show in the top menu" | Show in the top menu |

## Security

- The token is never saved. The settings hold only the name of the environment variable. The token is not in the
  database, never rendered in a page (the settings page only says whether the variable is set), never written to the log and
  never part of an error message; anything that would carry it is scrubbed first. Tests check each of these.
- The variable name is restricted to `GLITCHTIP_*`. Without that, whoever may edit the plugin settings could name any
  variable of the server, such as `SECRET_KEY_BASE` or a database password, and have it sent to the address they typed. The
  form refuses other names, and at run time a name outside the prefix is ignored: the token counts as missing and the
  environment is not read.
- The token goes only to the saved host. It is sent to the host of the GlitchTip address (plus the allowed hosts, when you
  list any). Redirects are never followed, so a GlitchTip that answers with a redirect to another host does not get the
  token there; the block shows "Status unavailable".
- https is required, except for a loopback host (`localhost`, `127.0.0.1`, `::1`). For GlitchTip on a network you trust
  without TLS, check "Allow plain http"; the token then travels unencrypted.
- Everything GlitchTip sends is escaped where it is shown.
- Read access is enough. Give the token the least it needs: reading issues.

## Theming

The block uses plain CSS (`assets/stylesheets/rubylode_glitchtip.css`), and every color and size is a
`--rubylode-glitchtip-*` custom property set on `.rubylode-glitchtip-errors`. Where Redmine 7 has a color variable the
default follows it, the dark palette follows the system setting, and a theme that marks its dark mode on the page wins over
that.

| Property | Used for |
|---|---|
| `--rubylode-glitchtip-text`, `-text-muted` | text, and the project, culprit and hints |
| `--rubylode-glitchtip-border` | table borders and row dividers |
| `--rubylode-glitchtip-header-background` | the table header |
| `--rubylode-glitchtip-row-hover-background` | the row under the pointer |
| `--rubylode-glitchtip-clear-color`, `-clear-background` | the "No errors need attention" summary |
| `--rubylode-glitchtip-attention-color`, `-attention-background` | the "N issues need attention" summary |
| `--rubylode-glitchtip-unavailable-color`, `-unavailable-background` | the "Status unavailable" summary |
| `--rubylode-glitchtip-fatal-color`, `-error-color`, `-warning-color`, `-info-color`, `-unknown-color` | the level dot (info also paints debug) |
| `--rubylode-glitchtip-link-color` | links |
| `--rubylode-glitchtip-dot-size`, `-radius`, `-gap` | dot size, corner radius, spacing |
| `--rubylode-glitchtip-summary-font-size`, `-culprit-font-size` | summary and culprit text |

## Try it

A throwaway Redmine 7 runs from this folder, with a fake GlitchTip next to it (`test/support/fake_glitchtip_server.rb`):

    ruby bin/demo up                 start both on http://localhost:3014 and load the demo data
    ruby bin/demo scenario none      switch the fake GlitchTip: several, none, unavailable or hostile
    ruby bin/demo restart            pick up a change to the plugin
    ruby bin/demo reset              wipe it

Sign in as `admin` / `admin`, or as `sam.rivera` / `demo-password-1`. The page is `/status/glitchtip`, the macro is on the
Storefront project's wiki, and the block is on My page. Everything in the fake GlitchTip is made up.

The screenshots above come from `node script/screenshots.mjs` ([Playwright](https://playwright.dev); the script's header says
how to install it).

## Troubleshooting

If the cache store cannot be read or written (a cache file owned by another user, a full disk), the plugin logs a warning with the error class and message, treats the cache as empty and asks GlitchTip again. The page still renders.

If the block is missing after an upgrade from 1.x, check that step 2 of the install ran: it moves the saved settings to the new names. Run it again, it is safe to repeat.

## Tests

    bin/test                                         all unit and integration tests
    bin/test test/unit/attention_rule_test.rb        one file

They run in a Redmine 7 image with its test gems (`docker/test.Dockerfile`). When a checkout of the Status plugin sits next
to this folder (`../redmine-rubylode-status`), `bin/test` mounts it read-only beside this plugin, so the tests also run against
its real registry; set `WITHOUT_STATUS_PLUGIN=1` to leave it out. The rule, the settings, the client and the report are plain
Ruby classes with unit tests; the client is also tested over a real socket against the fake GlitchTip, and the integration
tests cover the page, the macro, the My page block, the settings form and the token's secrecy.

Pull Requests are welcome!

## Releasing

Push a `vX.Y.Z` tag whose version matches `version` in `init.rb` and has an entry in `CHANGELOG.md`. CI runs the tests, builds `redmine_rubylode_glitchtip-X.Y.Z.zip` and publishes the GitHub release with the changelog entry as its notes. To build a release for a tag that already exists, use Actions, release, Run workflow.

The text to paste when listing the plugin on www.redmine.org, and how to read the result of Check for updates, is in [docs/redmine-org-listing.md](docs/redmine-org-listing.md).

## License

GNU General Public License, version 2 or (at your option) any later version, the same as Redmine. See `LICENSE`.

Copyright (C) 2026  Nick Gorbikoff

No warranty, as the GPL says. The plugin sends an API token to the GlitchTip address you configure, so keep the token read-only and try the plugin on a copy of your tracker first. I tested it in CI with the Rubylode plugins' own test suites on Redmine 7.0, 6.1, 6.0 and 5.1, against a fake GlitchTip built from its published API description, not against a running GlitchTip.
