# Rubylode GlitchTip: recent errors that need attention, in Redmine
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module RedmineRubylodeGlitchtip
  PLUGIN_ID = :redmine_rubylode_glitchtip

  # What a fresh install starts with. Everything here is a plugin setting except the token, which is only ever read from
  # the environment variable named by "token_environment_variable".
  module Defaults
    SETTINGS = {
      "base_url" => "",
      "organization_slug" => "",
      "token_environment_variable" => "GLITCHTIP_API_TOKEN",
      "allowed_hosts" => "",
      "allow_plain_http" => "0",
      "lookback_hours" => "24",
      "minimum_event_count" => "1",
      "levels" => %w[error fatal].freeze,
      "maximum_rows" => "10",
      "project_allow_list" => "",
      "cache_seconds" => "60",
      "failure_cache_seconds" => "30",
      "timeout_seconds" => "2",
      "block_title" => "Errors needing attention",
      "visibility" => "logged_in",
      "show_on_my_page" => "1",
      "show_on_welcome_page" => "0",
      "welcome_page_column" => "right",
      "show_on_project_overview" => "0",
      "project_overview_column" => "right",
      "path_patterns" => "",
      "show_in_top_menu" => "0"
    }.freeze
  end
end
