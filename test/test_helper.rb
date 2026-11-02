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

require File.expand_path("../../../test/test_helper", __dir__)
require_relative "support/fake_glitchtip_server"

module RubylodeGlitchtipTestHelpers
  PLUGIN_ID = RedmineRubylodeGlitchtip::PLUGIN_ID
  BASE_URL = "https://glitchtip.example.com".freeze
  ORGANIZATION = "example-org".freeze
  # The moment the unit tests treat as "now", so the look-back window is the same on every run.
  NOW = Time.utc(2026, 11, 1, 12, 0, 0)

  def issue_hash(overrides = {})
    {
      id: "101", short_id: "WEB-1", title: "NoMethodError: undefined method 'name' for nil", culprit: "app/models/user.rb",
      level: "error", count: 5, first_seen: (NOW - 3 * 3600).iso8601, last_seen: (NOW - 600).iso8601,
      status: "unresolved", project_slug: "web", project_name: "Web"
    }.merge(overrides)
  end

  def build_issue(overrides = {})
    RubylodeGlitchtip::Issue.new(**issue_hash(overrides))
  end

  def configure_plugin(overrides = {})
    settings = RedmineRubylodeGlitchtip::Defaults::SETTINGS.merge(
      "base_url" => BASE_URL, "organization_slug" => ORGANIZATION
    ).merge(overrides.transform_keys(&:to_s))
    Setting.send(:"plugin_#{PLUGIN_ID}=", settings)
  end

  def use_memory_cache
    @original_cache = RubylodeGlitchtip::ErrorsReport.cache
    RubylodeGlitchtip::ErrorsReport.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def restore_cache
    RubylodeGlitchtip::ErrorsReport.cache = @original_cache
  end

  # Puts GlitchTip's answer where the block looks for it, as if GlitchTip had just been asked.
  def publish_issues(issues, base_url: BASE_URL, organization: ORGANIZATION)
    RubylodeGlitchtip::ErrorsReport.cache.write(RubylodeGlitchtip::ErrorsReport.cache_key_for(base_url, organization),
                                                { "issues" => issues })
  end

  def publish_failure(reason, base_url: BASE_URL, organization: ORGANIZATION)
    RubylodeGlitchtip::ErrorsReport.cache.write(RubylodeGlitchtip::ErrorsReport.cache_key_for(base_url, organization),
                                                { "failure" => reason })
  end
end
