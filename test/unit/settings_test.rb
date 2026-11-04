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

class RubylodeGlitchtip::SettingsTest < ActiveSupport::TestCase
  def configuration(settings = {})
    RubylodeGlitchtip::Settings.new(settings)
  end

  test "an empty configuration has the documented defaults" do
    result = configuration

    assert_equal 24, result.look_back_hours
    assert_equal 1, result.minimum_event_count
    assert_equal %w[error fatal], result.levels
    assert_equal 10, result.maximum_rows
    assert_equal [], result.project_allow_list
    assert_equal 60, result.cache_seconds
    assert_equal 30, result.failure_cache_seconds
    assert_equal 2, result.timeout_seconds
    assert_equal "GLITCHTIP_API_TOKEN", result.token_environment_variable
    assert_equal "logged_in", result.visibility
    refute result.configured?
  end

  test "no placement is on by default, with the columns on the right" do
    result = configuration

    refute result.show_on_my_page?
    refute result.show_on_welcome_page?
    assert_equal "right", result.welcome_page_column
    refute result.show_on_project_overview?
    assert_equal "right", result.project_overview_column
    refute result.show_on_matching_pages?
    assert_empty result.matching_page_paths
    refute result.show_in_top_menu?
  end

  test "placements are switched on with 1 and columns fall back to the right" do
    result = configuration("show_on_my_page" => "1", "show_on_welcome_page" => "1", "welcome_page_column" => "left",
                           "show_on_project_overview" => "1", "project_overview_column" => "middle",
                           "show_on_matching_pages" => "1", "matching_page_paths" => "/issues\n/projects/*/issues", "show_in_top_menu" => "1")

    assert result.show_on_my_page?
    assert result.show_on_welcome_page?
    assert_equal "left", result.welcome_page_column
    assert result.show_on_project_overview?
    assert_equal "right", result.project_overview_column
    assert result.show_on_matching_pages?
    assert_equal ["/issues", "/projects/*/issues"], result.matching_page_paths
    assert result.show_in_top_menu?
  end

  test "the Status plugin counts as installed only while its registry exists" do
    registry_defined = defined?(::RubylodeStatus::Registry) ? true : false

    assert_equal registry_defined, RubylodeGlitchtip::Settings.status_plugin_installed?
  end

  test "the block title defaults to Errors" do
    assert_equal "Errors", configuration.block_title
  end

  test "it is configured once it has a web address and an organization" do
    assert configuration("base_url" => "https://g.example.com", "organization_slug" => "org").configured?
    refute configuration("base_url" => "https://g.example.com").configured?
    refute configuration("organization_slug" => "org").configured?
  end

  test "the base url loses a trailing slash" do
    assert_equal "https://g.example.com", configuration("base_url" => " https://g.example.com/ ").base_url
  end

  test "numbers that are not whole numbers fall back to the default and small ones are raised to the minimum" do
    result = configuration("look_back_hours" => "soon", "maximum_rows" => "0", "timeout_seconds" => "0", "cache_seconds" => "-5")

    assert_equal 24, result.look_back_hours
    assert_equal 1, result.maximum_rows
    assert_equal 1, result.timeout_seconds
    assert_equal 0, result.cache_seconds
  end

  test "levels accept an array or a comma separated string and drop unknown names" do
    assert_equal %w[warning fatal], configuration("levels" => %w[warning fatal nonsense]).levels
    assert_equal %w[info error], configuration("levels" => "info, error").levels
    assert_equal %w[error fatal], configuration("levels" => [""]).levels
  end

  test "the project allow-list splits on commas, spaces and lines" do
    assert_equal %w[web billing api], configuration("project_allow_list" => "web, Billing\napi").project_allow_list
  end

  test "the token variable must start with GLITCHTIP_" do
    assert configuration("token_environment_variable" => "GLITCHTIP_PRODUCTION_TOKEN").token_variable_allowed?
    assert configuration.token_variable_allowed?
    %w[SECRET_KEY_BASE DATABASE_PASSWORD MY_TOKEN glitchtip_token GLITCHTIP-X PATH].each do |name|
      refute configuration("token_environment_variable" => name).token_variable_allowed?, "#{name} must be refused"
    end
  end

  test "a variable that is not allowed is never read from the environment" do
    ENV["SECRET_KEY_BASE_FOR_TEST"] = "do-not-read"
    ENV["GLITCHTIP_UNIT_TEST_TOKEN"] = "allowed-value"

    assert_equal "", configuration("token_environment_variable" => "SECRET_KEY_BASE_FOR_TEST").token
    assert_equal "allowed-value", configuration("token_environment_variable" => "GLITCHTIP_UNIT_TEST_TOKEN").token
  ensure
    ENV.delete("SECRET_KEY_BASE_FOR_TEST")
    ENV.delete("GLITCHTIP_UNIT_TEST_TOKEN")
  end

  test "the token goes to the host of the base url plus the extra hosts, nowhere else" do
    result = configuration("base_url" => "https://g.example.com/path", "allowed_hosts" => "Mirror.example.com, other.example.org")

    assert_equal %w[g.example.com mirror.example.com other.example.org], result.allowed_hosts
    assert_equal %w[g.example.com], configuration("base_url" => "https://g.example.com").allowed_hosts
  end

  test "https is required unless the host is loopback or plain http is allowed" do
    assert configuration("base_url" => "https://g.example.com").transport_allowed?
    refute configuration("base_url" => "http://g.example.com").transport_allowed?
    assert configuration("base_url" => "http://g.example.com", "allow_plain_http" => "1").transport_allowed?
    %w[http://localhost:8000 http://127.0.0.1:9100 http://[::1]:3000].each do |address|
      assert configuration("base_url" => address).transport_allowed?, address
    end
    refute configuration("base_url" => "ftp://g.example.com").transport_allowed?
  end

  test "visibility decides who may see the block" do
    everyone = configuration("visibility" => "logged_in")
    admins = configuration("visibility" => "admins")
    member = User.new
    member.define_singleton_method(:logged?) { true }
    member.define_singleton_method(:admin?) { false }
    administrator = User.new
    administrator.define_singleton_method(:logged?) { true }
    administrator.define_singleton_method(:admin?) { true }

    assert everyone.visible_to?(member)
    refute admins.visible_to?(member)
    assert admins.visible_to?(administrator)
    refute everyone.visible_to?(User.anonymous)
  end

  test "the block title is never empty" do
    assert_equal "Errors", configuration("block_title" => "  ").block_title
    assert_equal "Alerts", configuration("block_title" => "Alerts").block_title
  end
end
