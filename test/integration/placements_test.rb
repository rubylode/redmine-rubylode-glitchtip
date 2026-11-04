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

# Where the block shows: the welcome page, the project Overview, any page matching a path, My page, the top menu, and
# the macro in the places Redmine formats text.
class RubylodeGlitchtip::PlacementsTest < Redmine::IntegrationTest
  include RubylodeGlitchtipTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :issues, :news, :versions, :workflows, :queries

  SUMMARY = ".rubylode-glitchtip-errors-summary".freeze

  setup do
    use_memory_cache
    now = Time.now.utc
    @issue = issue_hash(id: "7", title: "Boom", first_seen: (now - 3600).iso8601, last_seen: (now - 300).iso8601)
    publish_issues([@issue])
  end

  teardown do
    restore_cache
  end

  def block_count
    css_select(".rubylode-glitchtip-errors").size
  end

  test "nothing is placed anywhere by default" do
    configure_plugin
    log_user("jsmith", "jsmith")

    ["/", "/projects/ecookbook", "/issues", "/projects/ecookbook/issues"].each do |path|
      get path
      assert_response :success
      assert_equal 0, block_count, "#{path} must not show the block"
    end
  end

  test "the welcome page shows the block in the chosen column only" do
    configure_plugin("show_on_welcome_page" => "1", "welcome_page_column" => "left")
    log_user("jsmith", "jsmith")
    get "/"

    assert_select ".splitcontentleft #{SUMMARY}", text: "1 issue needs attention, 5 events"
    assert_select ".splitcontentright .rubylode-glitchtip-errors", 0

    configure_plugin("show_on_welcome_page" => "1", "welcome_page_column" => "right")
    get "/"

    assert_select ".splitcontentright #{SUMMARY}"
    assert_select ".splitcontentleft .rubylode-glitchtip-errors", 0
  end

  test "the project Overview page shows the block in the chosen column only" do
    configure_plugin("show_on_project_overview" => "1", "project_overview_column" => "right")
    log_user("jsmith", "jsmith")
    get "/projects/ecookbook"

    assert_response :success
    assert_select ".splitcontentright #{SUMMARY}", text: "1 issue needs attention, 5 events"
    assert_select ".splitcontentleft .rubylode-glitchtip-errors", 0

    configure_plugin("show_on_project_overview" => "1", "project_overview_column" => "left")
    get "/projects/ecookbook"

    assert_select ".splitcontentleft #{SUMMARY}"
    assert_select ".splitcontentright .rubylode-glitchtip-errors", 0
  end

  test "a page whose path matches a pattern gets the compact block after its content, with its own stylesheet" do
    configure_plugin("matching_page_paths" => "/issues\n/projects/*/roadmap")
    log_user("jsmith", "jsmith")
    get "/issues?set_filter=1&status_id=o"

    assert_response :success
    assert_equal 1, block_count
    assert_select "#content > .rubylode-glitchtip-errors.is-compact #{SUMMARY}", text: "1 issue needs attention, 5 events"
    assert_select "#content link[rel=stylesheet][href*=rubylode_glitchtip]"

    get "/projects/ecookbook/roadmap"
    assert_equal 1, block_count
  end

  test "a page that does not match gets nothing" do
    configure_plugin("matching_page_paths" => "/issues")
    log_user("jsmith", "jsmith")
    get "/projects/ecookbook"

    assert_equal 0, block_count
  end

  test "a wildcard never reaches the settings, administration or sign-in pages" do
    configure_plugin("matching_page_paths" => "/*")
    log_user("admin", "admin")

    get "/settings"
    assert_equal 0, block_count
    get "/admin"
    assert_equal 0, block_count
    get "/settings/plugin/redmine_rubylode_glitchtip"
    assert_select ".rubylode-glitchtip-errors", 0
    get "/issues"
    assert_equal 1, block_count
  end

  test "a path that is listed explicitly does match, even a protected one" do
    configure_plugin("matching_page_paths" => "/admin")
    log_user("admin", "admin")
    get "/admin"

    assert_equal 1, block_count
  end

  test "the block's own page is not drawn twice by a wildcard" do
    configure_plugin("matching_page_paths" => "/*")
    log_user("jsmith", "jsmith")
    get "/status/glitchtip"

    assert_equal 1, block_count
  end

  test "every placement honours the permission setting" do
    configure_plugin("visibility" => "admins", "show_on_welcome_page" => "1", "show_on_project_overview" => "1",
                     "matching_page_paths" => "/issues")
    log_user("jsmith", "jsmith")

    ["/", "/projects/ecookbook", "/issues"].each do |path|
      get path
      assert_equal 0, block_count, "#{path} must not show the block to a person the settings do not allow"
    end
  end

  test "every placement honours the permission setting for an administrator too: they do see it" do
    configure_plugin("visibility" => "admins", "show_on_welcome_page" => "1", "matching_page_paths" => "/issues")
    log_user("admin", "admin")

    get "/"
    assert_equal 1, block_count
    get "/issues"
    assert_equal 1, block_count
  end

  test "an anonymous visitor never sees the block anywhere" do
    configure_plugin("show_on_welcome_page" => "1", "matching_page_paths" => "/projects")
    get "/"
    assert_equal 0, block_count
    get "/projects"
    assert_equal 0, block_count
  end

  test "the placements share one cached answer: GlitchTip is asked once" do
    restore_cache
    server = FakeGlitchtipServer.new(token: "placements-token", organization: ORGANIZATION).start
    ENV["GLITCHTIP_PLACEMENTS_TEST_TOKEN"] = "placements-token"
    use_memory_cache
    configure_plugin("base_url" => server.base_url, "token_environment_variable" => "GLITCHTIP_PLACEMENTS_TEST_TOKEN",
                     "show_on_welcome_page" => "1", "show_on_project_overview" => "1", "matching_page_paths" => "/issues")
    log_user("jsmith", "jsmith")

    ["/", "/projects/ecookbook", "/issues", "/status/glitchtip"].each { |path| get path }

    assert_equal 1, server.request_count
  ensure
    ENV.delete("GLITCHTIP_PLACEMENTS_TEST_TOKEN")
    server&.stop
  end

  test "a failure shows status unavailable on a placement and the page still renders" do
    publish_failure("GlitchTip answered 503")
    configure_plugin("show_on_welcome_page" => "1", "matching_page_paths" => "/issues")
    log_user("jsmith", "jsmith")

    get "/"
    assert_response :success
    assert_select ".rubylode-glitchtip-errors-summary.is-unavailable", text: "Status unavailable"
    get "/issues"
    assert_response :success
    assert_select ".rubylode-glitchtip-errors-summary.is-unavailable"
  end

  test "My page: a block a person added draws whatever the My page setting says" do
    preference = User.find(2).pref
    preference.my_page_layout = { "top" => ["rubylode_glitchtip_status"] }
    preference.save!
    log_user("jsmith", "jsmith")

    [["1"], ["0"]].each do |(setting)|
      configure_plugin("show_on_my_page" => setting)
      get "/my/page"
      assert_select "#block-rubylode_glitchtip_status #{SUMMARY}"
    end
  end

  test "My page: the setting adds the block to the default My page, for people who have not arranged their own" do
    log_user("jsmith", "jsmith")

    configure_plugin("show_on_my_page" => "1")
    get "/my/page"
    assert_select "#block-rubylode_glitchtip_status #{SUMMARY}"

    configure_plugin("show_on_my_page" => "0")
    get "/my/page"
    assert_select "#block-rubylode_glitchtip_status", 0
  end

  test "My page: the setting leaves a layout a person saved alone" do
    preference = User.find(2).pref
    preference.my_page_layout = { "left" => ["issuesassignedtome"] }
    preference.save!
    log_user("jsmith", "jsmith")
    configure_plugin("show_on_my_page" => "1")
    get "/my/page"

    assert_select "#block-rubylode_glitchtip_status", 0
    assert_select "#block-issuesassignedtome"
  end

  test "My page: a layout saved with the block's old name keeps drawing it" do
    preference = User.find(2).pref
    preference.my_page_layout = { "top" => ["rubylode_glitchtip_errors"] }
    preference.save!
    log_user("jsmith", "jsmith")
    configure_plugin
    get "/my/page"

    assert_select "#block-rubylode_glitchtip_errors #{SUMMARY}"
  end

  test "the macro works in the welcome text" do
    configure_plugin
    Setting.welcome_text = "Hello!\n\n{{glitchtip_status}}"
    log_user("jsmith", "jsmith")
    get "/"

    assert_select ".wiki #{SUMMARY}", text: "1 issue needs attention, 5 events"
  ensure
    Setting.welcome_text = ""
  end

  test "the macro works in a news description" do
    configure_plugin
    news = News.find(1)
    news.update_columns(description: "Status:\n\n{{glitchtip_status}}")
    log_user("jsmith", "jsmith")
    get "/news/1"

    assert_select "#{SUMMARY}", text: "1 issue needs attention, 5 events"
  end

  test "the macro works in an issue description" do
    configure_plugin
    Issue.find(1).update_columns(description: "See:\n\n{{glitchtip_status}}")
    log_user("jsmith", "jsmith")
    get "/issues/1"

    assert_response :success
    assert_select ".description #{SUMMARY}", text: "1 issue needs attention, 5 events"
  end

  test "the top menu link shows only while it is checked and the person may see the block" do
    configure_plugin("show_in_top_menu" => "1", "block_title" => "Production errors")
    log_user("jsmith", "jsmith")
    with_status_plugin_installed(false) do
      get "/"
      assert_select "#top-menu a[href=?]", "/status/glitchtip", text: "Production errors"

      configure_plugin("show_in_top_menu" => "0")
      get "/"
      assert_select "#top-menu a[href=?]", "/status/glitchtip", 0

      configure_plugin("show_in_top_menu" => "1", "visibility" => "admins")
      get "/"
      assert_select "#top-menu a[href=?]", "/status/glitchtip", 0
    end
  end

  test "the plugin's own top menu link goes while the Status plugin is installed" do
    configure_plugin("show_in_top_menu" => "1")
    log_user("jsmith", "jsmith")
    with_status_plugin_installed(true) do
      get "/"
      assert_select "#top-menu a[href=?]", "/status/glitchtip", 0
    end
  end

  test "matching pages need the box checked as well as paths" do
    configure_plugin("matching_page_paths" => "/issues", "show_on_matching_pages" => "0")
    log_user("jsmith", "jsmith")
    get "/issues"

    assert_equal 0, block_count
  end

  test "the old macro name still answers" do
    configure_plugin
    Setting.welcome_text = "Hello!\n\n{{glitchtip_errors}}"
    log_user("jsmith", "jsmith")
    get "/"

    assert_select ".wiki #{SUMMARY}", text: "1 issue needs attention, 5 events"
  ensure
    Setting.welcome_text = ""
  end
end

