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

# A status block never takes a page down: a cache store that raises, or a report object that raises, still gives a 200.
class RubylodeGlitchtip::CacheFailureTest < Redmine::IntegrationTest
  include RubylodeGlitchtipTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :issues, :news, :versions, :workflows, :queries, :wikis,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  SUMMARY = ".rubylode-glitchtip-errors-summary".freeze
  TOKEN = "cache-failure-token-5c1d88".freeze
  TOKEN_VARIABLE = "GLITCHTIP_CACHE_FAILURE_TEST_TOKEN".freeze

  setup do
    use_memory_cache
    @server = FakeGlitchtipServer.new(token: TOKEN, organization: ORGANIZATION).start
    ENV[TOKEN_VARIABLE] = TOKEN
    configure_plugin("base_url" => @server.base_url, "token_environment_variable" => TOKEN_VARIABLE,
                     "show_on_welcome_page" => "1")
  end

  teardown do
    ENV.delete(TOKEN_VARIABLE)
    @server.stop
    restore_cache
  end

  def raising_report(&block)
    replacing_method(RubylodeGlitchtip::ErrorsReport, :current, ->(*) { raise IOError, "report object broke" }, &block)
  end

  test "the welcome page answers 200 with the block when the cache store raises" do
    RubylodeGlitchtip::ErrorsReport.cache = RubylodeGlitchtipTestHelpers::UnwritableCache.new

    log_user("jsmith", "jsmith")
    get "/"

    assert_response :success
    assert_select "#{SUMMARY}.is-needs-attention"
  end

  test "the token is not in the log line written for a cache failure" do
    RubylodeGlitchtip::ErrorsReport.cache = RubylodeGlitchtipTestHelpers::UnwritableCache.new

    log_user("jsmith", "jsmith")
    log = captured_log { get "/" }

    assert_includes log, "Rubylode GlitchTip: cache read failed"
    refute_includes log, TOKEN
    refute_includes response.body, TOKEN
  end

  test "the welcome page answers 200 with status unavailable when the report object raises" do
    log_user("jsmith", "jsmith")
    raising_report { get "/" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable", text: "Status unavailable"
  end

  test "My page answers 200 with status unavailable when the report object raises" do
    preference = User.find(2).pref
    preference.my_page_layout = { "top" => ["rubylode_glitchtip_errors"] }
    preference.save!

    log_user("jsmith", "jsmith")
    raising_report { get "/my/page" }

    assert_response :success
    assert_select "#block-rubylode_glitchtip_errors #{SUMMARY}.is-unavailable"
  end

  test "the project overview answers 200 with status unavailable when the report object raises" do
    configure_plugin("show_on_project_overview" => "1")

    log_user("jsmith", "jsmith")
    raising_report { get "/projects/ecookbook" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable"
  end

  test "a page on the path list answers 200 with status unavailable when the report object raises" do
    configure_plugin("path_patterns" => "/issues")

    log_user("jsmith", "jsmith")
    raising_report { get "/issues" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable"
  end

  test "a wiki page with the macro answers 200 with status unavailable when the report object raises" do
    page = WikiPage.new(wiki: Project.find(1).wiki, title: "Errors_#{SecureRandom.hex(3)}")
    page.content = WikiContent.new(text: "{{glitchtip_errors}}", author: User.find(2))
    page.save!

    log_user("jsmith", "jsmith")
    raising_report { get "/projects/ecookbook/wiki/#{page.title}" }

    assert_response :success
    assert_select ".wiki #{SUMMARY}.is-unavailable"
  end

  test "the standalone page answers 200 with status unavailable when the report object raises" do
    log_user("jsmith", "jsmith")
    raising_report { get "/glitchtip_errors" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable"
  end

  test "an administrator sees the class name of the error in the hint, others do not" do
    log_user("admin", "admin")
    raising_report { get "/glitchtip_errors" }
    assert_select ".rubylode-glitchtip-errors-hint", text: /IOError/

    post "/logout"
    log_user("jsmith", "jsmith")
    raising_report { get "/glitchtip_errors" }
    assert_select ".rubylode-glitchtip-errors-hint", 0
  end
end
