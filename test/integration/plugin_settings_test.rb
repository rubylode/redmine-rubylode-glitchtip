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

class RubylodeGlitchtip::PluginSettingsTest < Redmine::IntegrationTest
  include RubylodeGlitchtipTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles

  SETTINGS_PATH = "/settings/plugin/redmine_rubylode_glitchtip".freeze

  GOOD_SETTINGS = {
    "base_url" => "https://glitchtip.example.com", "organization_slug" => "example-org",
    "token_environment_variable" => "GLITCHTIP_MY_TOKEN", "allowed_hosts" => "", "allow_plain_http" => "0",
    "look_back_hours" => "12", "minimum_event_count" => "2", "levels" => ["", "fatal", "error", "warning"],
    "maximum_rows" => "5", "project_allow_list" => "web, api", "cache_seconds" => "120", "failure_cache_seconds" => "15",
    "timeout_seconds" => "3", "block_title" => "Our errors", "visibility" => "admins"
  }.freeze

  setup do
    Setting.send(:"plugin_#{PLUGIN_ID}=", RubylodeGlitchtip::Settings::DEFAULTS.dup)
  end

  def saved
    Setting.send(:"plugin_#{PLUGIN_ID}")
  end

  test "the plugin is registered and its settings page opens with every field" do
    log_user("admin", "admin")
    get SETTINGS_PATH

    assert_response :success
    %w[base_url organization_slug token_environment_variable allowed_hosts allow_plain_http look_back_hours minimum_event_count
       maximum_rows project_allow_list block_title visibility cache_seconds failure_cache_seconds timeout_seconds].each do |field|
      assert_select "[name=?]", "settings[#{field}]"
    end
    assert_select "input[name=?]", "settings[levels][]", minimum: 5
    assert_select "input[name=?][value=?]", "settings[token_environment_variable]", "GLITCHTIP_API_TOKEN"
    assert_select "input#settings_levels_error[checked]"
    assert_select "input#settings_levels_warning[checked]", 0
  end

  test "good settings are saved as plugin settings" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS }

    assert_redirected_to SETTINGS_PATH
    configuration = RubylodeGlitchtip::Settings.current
    assert_equal "https://glitchtip.example.com", configuration.base_url
    assert_equal "GLITCHTIP_MY_TOKEN", configuration.token_environment_variable
    assert_equal %w[fatal error warning], configuration.levels
    assert_equal 12, configuration.look_back_hours
    assert_equal %w[web api], configuration.project_allow_list
    assert_equal "admins", configuration.visibility
  end

  test "a bad value shows the error, keeps what was typed and saves nothing" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("base_url" => "ftp://nope", "project_allow_list" => "bad slug!") }

    assert_response :unprocessable_entity
    assert_select "#errorExplanation li", 2
    assert_select "input[name=?][value=?]", "settings[base_url]", "ftp://nope"
    assert_equal "", saved["base_url"], "nothing was saved"
  end

  test "SECRET_KEY_BASE and DATABASE_PASSWORD are refused as the token variable and nothing is saved" do
    log_user("admin", "admin")
    %w[SECRET_KEY_BASE DATABASE_PASSWORD].each do |name|
      post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("token_environment_variable" => name) }

      assert_response :unprocessable_entity
      assert_select "#errorExplanation li", text: /GLITCHTIP_/
      assert_equal "GLITCHTIP_API_TOKEN", saved["token_environment_variable"]
    end
  end

  test "a plain http address is refused without the allow box and accepted with it" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("base_url" => "http://glitchtip.internal") }
    assert_response :unprocessable_entity

    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("base_url" => "http://glitchtip.internal", "allow_plain_http" => "1") }
    assert_redirected_to SETTINGS_PATH
    assert RubylodeGlitchtip::Settings.current.transport_allowed?
  end

  test "someone who is not an administrator cannot open or save the settings" do
    log_user("jsmith", "jsmith")

    get SETTINGS_PATH
    assert_response :forbidden
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS }
    assert_response :forbidden
    assert_equal "", saved["base_url"]
  end

  test "the plugin shows its project address and author on the Plugins page" do
    plugin = Redmine::Plugin.find(:redmine_rubylode_glitchtip)
    readme = File.read(File.expand_path("../../README.md", __dir__))
    repository_name = readme[%r{git clone https://github\.com/rubylode/([\w-]+)\.git}, 1]
    assert_equal "redmine-rubylode-glitchtip", repository_name
    assert_equal "https://github.com/rubylode/#{repository_name}", plugin.url
    assert_equal "Rubylode", plugin.author
    assert_equal "https://github.com/rubylode", plugin.author_url
  end
end
