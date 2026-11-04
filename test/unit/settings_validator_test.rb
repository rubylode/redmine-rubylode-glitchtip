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

require_relative "../test_helper"

class RubylodeGlitchtip::SettingsValidatorTest < ActiveSupport::TestCase
  GOOD = {
    "base_url" => "https://glitchtip.example.com", "allowed_hosts" => "", "allow_plain_http" => "0", "organization_slug" => "example-org",
    "token_environment_variable" => "GLITCHTIP_MY_TOKEN", "look_back_hours" => "12", "minimum_event_count" => "2",
    "levels" => %w[error fatal], "maximum_rows" => "5", "project_allow_list" => "web, api",
    "cache_seconds" => "0", "failure_cache_seconds" => "10", "timeout_seconds" => "3",
    "block_title" => "Errors", "visibility" => "admins"
  }.freeze

  def errors(overrides = {})
    RubylodeGlitchtip::SettingsValidator.errors_for(GOOD.merge(overrides))
  end

  test "good settings have no errors, and neither do empty ones" do
    assert_empty errors
    assert_empty RubylodeGlitchtip::SettingsValidator.errors_for({})
    assert_empty RubylodeGlitchtip::SettingsValidator.errors_for(nil)
  end

  test "the base url must be a web address" do
    assert_equal 1, errors("base_url" => "ftp://nope").size
    assert_equal 1, errors("base_url" => "glitchtip.example.com").size
    assert_empty errors("base_url" => "")
  end

  test "the organization slug may only use letters, digits, dashes and underscores" do
    assert_equal 1, errors("organization_slug" => "my org/../x").size
  end

  test "the token variable name must be a valid name" do
    assert_equal 1, errors("token_environment_variable" => "1BAD").size
  end

  test "a value that looks like a token is refused as a variable name" do
    assert_equal 1, errors("token_environment_variable" => "abc.def-ghi=").size
  end

  test "the token variable must start with GLITCHTIP_, so no other secret of the server can be named" do
    %w[SECRET_KEY_BASE DATABASE_PASSWORD PATH MY_TOKEN].each do |name|
      messages = errors("token_environment_variable" => name)
      assert_equal 1, messages.size, name
      assert_match(/GLITCHTIP_/, messages.first)
    end
    assert_empty errors("token_environment_variable" => "GLITCHTIP_EU_TOKEN")
  end

  test "a plain http address is refused unless it is loopback or plain http is allowed" do
    assert_equal 1, errors("base_url" => "http://glitchtip.example.com").size
    assert_empty errors("base_url" => "http://glitchtip.example.com", "allow_plain_http" => "1")
    assert_empty errors("base_url" => "http://localhost:8000")
    assert_empty errors("base_url" => "http://127.0.0.1:9100")
  end

  test "the extra hosts must be host names" do
    assert_empty errors("allowed_hosts" => "a.example.com, b.example.org")
    assert_equal 1, errors("allowed_hosts" => "https://a.example.com/x").size
  end

  test "numbers must be whole and at least their minimum" do
    assert_equal 1, errors("look_back_hours" => "0").size
    assert_equal 1, errors("maximum_rows" => "many").size
    assert_equal 1, errors("maximum_rows" => "101").size
    assert_equal 1, errors("timeout_seconds" => "0").size
    assert_equal 1, errors("minimum_event_count" => "-1").size
  end

  test "levels must be known and at least one must be chosen" do
    assert_equal 1, errors("levels" => %w[error loud]).size
    assert_equal 1, errors("levels" => [""]).size
  end

  test "project slugs must look like slugs" do
    assert_equal 1, errors("project_allow_list" => "web, bad slug!").size
  end

  test "the columns must be left or right" do
    assert_empty errors("welcome_page_column" => "left", "project_overview_column" => "right")
    assert_equal 1, errors("welcome_page_column" => "middle").size
    assert_equal 1, errors("project_overview_column" => "").size
  end

  test "good path patterns are accepted" do
    assert_empty errors("matching_page_paths" => "/issues\n/projects/*/issues\n\n/wiki/*")
  end

  test "a path pattern must start with a slash and carry no scheme, host, spaces or control characters" do
    ["issues", "https://example.com/issues", "//example.com/issues", "/issues /x", "/is\tsues", "example.com/issues"].each do |pattern|
      assert_equal 1, errors("matching_page_paths" => pattern).size, pattern.inspect
    end
  end

  test "a path pattern has a maximum length and the list a maximum size" do
    assert_equal 1, errors("matching_page_paths" => "/#{'a' * 200}").size
    assert_equal 1, errors("matching_page_paths" => (1..21).map { |number| "/page#{number}" }.join("\n")).size
  end

  test "each bad path line is reported with its line number" do
    messages = errors("matching_page_paths" => "/issues\nbad\n/ok\nalso bad")

    assert_equal 2, messages.size
    assert_match(/line 2/, messages.first)
    assert_match(/line 4/, messages.last)
  end

  test "the title cannot be blank and visibility must be a listed choice" do
    assert_equal 1, errors("block_title" => " ").size
    assert_equal 1, errors("visibility" => "everyone").size
  end

  test "messages never contain the submitted token variable value beyond what was typed in the field" do
    assert errors("token_environment_variable" => "1BAD").none? { |message| message.include?("1BAD") }
  end
end
