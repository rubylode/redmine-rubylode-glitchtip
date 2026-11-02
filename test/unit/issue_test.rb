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

class RubylodeGlitchtip::IssueTest < ActiveSupport::TestCase
  include RubylodeGlitchtipTestHelpers

  test "times are parsed and the count becomes a number" do
    issue = build_issue(count: "12")

    assert_equal 12, issue.count
    assert_equal NOW - 600, issue.last_seen
    assert_kind_of Time, issue.first_seen
  end

  test "from_api reads GlitchTip's issue shape, where the count is a string" do
    issue = RubylodeGlitchtip::Issue.from_api(
      "id" => "77", "shortId" => "API-7", "title" => "Boom", "culprit" => "worker.rb", "level" => "fatal", "count" => "31",
      "status" => "unresolved", "firstSeen" => "2026-11-01T08:00:00Z", "lastSeen" => "2026-11-01T11:00:00.123456Z",
      "project" => { "id" => "3", "slug" => "api", "name" => "API" }, "permalink" => "Not implemented"
    )

    assert_equal "77", issue.id
    assert_equal 31, issue.count
    assert_equal "api", issue.project_slug
    assert_equal "API", issue.project_name
    assert_equal "API-7", issue.short_id
  end

  test "from_api gives nil for an item that is not an issue" do
    assert_nil RubylodeGlitchtip::Issue.from_api("nonsense" => 1)
    assert_nil RubylodeGlitchtip::Issue.from_api("id" => "1", "lastSeen" => "not a date", "level" => "error")
    assert_nil RubylodeGlitchtip::Issue.from_api("something else")
  end

  test "to_h and new round trip" do
    issue = build_issue

    assert_equal issue, RubylodeGlitchtip::Issue.new(**issue.to_h)
  end

  test "an id that is not made of digits is refused, so it can never shape a link" do
    assert_nil RubylodeGlitchtip::Issue.from_api("id" => "../../x", "level" => "error", "status" => "unresolved",
                                                 "lastSeen" => "2026-11-01T08:00:00Z", "count" => "1")
  end
end
