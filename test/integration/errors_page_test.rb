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

class RubylodeGlitchtip::ErrorsPageTest < Redmine::IntegrationTest
  include RubylodeGlitchtipTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issue_statuses, :trackers, :projects_trackers, :enumerations, :enabled_modules

  setup do
    use_memory_cache
    configure_plugin
  end

  teardown do
    restore_cache
  end

  def recent(overrides = {})
    now = Time.now.utc
    issue_hash({ first_seen: (now - 3600).iso8601, last_seen: (now - 300).iso8601 }.merge(overrides))
  end

  test "the page shows a table of the issues that need attention with project, level, events, last seen and a link" do
    publish_issues([recent(id: "7", title: "Boom in checkout", count: 12, level: "fatal", culprit: "cart.rb"),
                    recent(id: "8", title: "Quiet one", status: "resolved")])

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_response :success
    assert_select ".rubylode-glitchtip-errors-summary.is-needs-attention", text: "1 issue needs attention, 12 events"
    assert_select "tr.is-fatal td.rubylode-glitchtip-errors-title-cell a[href=?]", "#{BASE_URL}/#{ORGANIZATION}/issues/7", text: "Boom in checkout"
    assert_select "tr.is-fatal .rubylode-glitchtip-errors-culprit", text: "cart.rb"
    assert_select "tr.is-fatal td.rubylode-glitchtip-errors-project", text: "Web"
    assert_select "tr.is-fatal td.rubylode-glitchtip-errors-level", text: "Fatal"
    assert_select "tr.is-fatal td.rubylode-glitchtip-errors-events", text: "12"
    assert_select "tr.is-fatal td.rubylode-glitchtip-errors-last-seen", text: /ago/
    assert_select "tbody tr", 1
  end

  test "the issue link opens in a new tab without leaking the referrer" do
    publish_issues([recent(id: "7")])

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_select "a.rubylode-glitchtip-errors-link[target=_blank][rel~=noopener][rel~=noreferrer]"
  end

  test "with nothing to report the summary says no errors need attention" do
    publish_issues([recent(status: "resolved")])

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_select ".rubylode-glitchtip-errors-summary.is-clear", text: "No errors need attention"
    assert_select ".rubylode-glitchtip-errors-table", 0
  end

  test "rows are ordered by level, then events, and the rest are counted in a line below" do
    configure_plugin("maximum_rows" => "2")
    publish_issues([recent(id: "1", level: "error", count: 5), recent(id: "2", level: "fatal", count: 1),
                    recent(id: "3", level: "error", count: 50), recent(id: "4", level: "error", count: 2)])

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_select "tbody tr:nth-child(1) a[href$='/issues/2']"
    assert_select "tbody tr:nth-child(2) a[href$='/issues/3']"
    assert_select "tbody tr", 2
    assert_select ".rubylode-glitchtip-errors-more", text: "and 2 more issues"
    assert_select ".rubylode-glitchtip-errors-summary", text: "4 issues need attention, 58 events"
  end

  test "the block title is the setting" do
    configure_plugin("block_title" => "Production errors")
    publish_issues([])

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_select "h2", text: "Production errors"
  end

  test "a hostile issue title, culprit and project name are escaped everywhere" do
    hostile = %(<script>alert("owned")</script><img src=x onerror=alert(1)>)
    publish_issues([recent(title: hostile, culprit: "<b>bold</b>", project_name: "<i>Shop</i>")])

    log_user("admin", "admin")
    get "/glitchtip_errors"

    assert_response :success
    refute_includes response.body, "<script>alert(\"owned\")"
    refute_includes response.body, "<img src=x"
    refute_includes response.body, "<b>bold</b>"
    refute_includes response.body, "<i>Shop</i>"
    assert_includes response.body, "&lt;script&gt;alert(&quot;owned&quot;)&lt;/script&gt;"
    assert_select ".rubylode-glitchtip-errors-link", text: hostile
    assert_select ".rubylode-glitchtip-errors script", 0
    assert_select ".rubylode-glitchtip-errors img", 0
  end

  test "an issue whose id is not made of digits is skipped, so it can never shape a link" do
    publish_issues([recent.merge(id: "../../evil"), recent(id: "9")])

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "a[href*='evil']", 0
  end

  test "when GlitchTip gives no answer the page still renders with status unavailable" do
    publish_failure("GlitchTip answered 503")

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_response :success
    assert_select ".rubylode-glitchtip-errors-summary.is-unavailable", text: "Status unavailable"
    assert_select ".rubylode-glitchtip-errors-table", 0
    assert_select ".rubylode-glitchtip-errors-hint", 0, "the reason is for administrators only"
  end

  test "an administrator sees why the status is unavailable" do
    publish_failure("GlitchTip answered 503")

    log_user("admin", "admin")
    get "/glitchtip_errors"

    assert_select ".rubylode-glitchtip-errors-hint", text: /GlitchTip answered 503/
  end

  test "a missing token shows status unavailable and the page renders" do
    ENV.delete("GLITCHTIP_API_TOKEN")
    configure_plugin("base_url" => "http://127.0.0.1:9")

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"

    assert_response :success
    assert_select ".rubylode-glitchtip-errors-summary", text: "Status unavailable"
  end

  test "not configured: administrators get a hint with a link to the settings, everyone else gets an empty page" do
    configure_plugin("base_url" => "")

    log_user("admin", "admin")
    get "/glitchtip_errors"
    assert_select ".rubylode-glitchtip-errors-hint a[href=?]", "/settings/plugin/redmine_rubylode_glitchtip"
  end

  test "not configured: everyone else gets an empty page" do
    configure_plugin("base_url" => "")

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"
    assert_response :success
    assert_select ".rubylode-glitchtip-errors", 0
  end

  test "administrators only: an ordinary user is refused" do
    configure_plugin("visibility" => "admins")
    publish_issues([recent])

    log_user("jsmith", "jsmith")
    get "/glitchtip_errors"
    assert_response :forbidden
  end

  test "administrators only: an administrator sees the page" do
    configure_plugin("visibility" => "admins")
    publish_issues([recent])

    log_user("admin", "admin")
    get "/glitchtip_errors"
    assert_response :success
  end

  test "an anonymous visitor is sent to sign in" do
    get "/glitchtip_errors"

    assert_redirected_to %r{/login}
  end
end
