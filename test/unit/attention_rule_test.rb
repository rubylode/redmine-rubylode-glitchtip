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

class RubylodeGlitchtip::AttentionRuleTest < ActiveSupport::TestCase
  include RubylodeGlitchtipTestHelpers

  def rule(**overrides)
    RubylodeGlitchtip::AttentionRule.new(
      **{ now: NOW, lookback_hours: 24, minimum_event_count: 1, levels: %w[error fatal], project_slugs: [] }.merge(overrides)
    )
  end

  test "an unresolved error seen inside the window needs attention" do
    assert_equal ["101"], rule.select([build_issue]).map(&:id)
  end

  test "resolved and ignored issues never need attention" do
    issues = [build_issue(id: "1", status: "resolved"), build_issue(id: "2", status: "ignored"), build_issue(id: "3")]

    assert_equal ["3"], rule.select(issues).map(&:id)
  end

  test "an issue last seen before the window does not need attention, one inside it does" do
    old = build_issue(id: "1", last_seen: (NOW - 25 * 3600).iso8601)
    inside = build_issue(id: "2", last_seen: (NOW - 23 * 3600).iso8601)

    assert_equal ["2"], rule.select([old, inside]).map(&:id)
  end

  test "an issue first seen long ago but seen again inside the window is recurring and counts" do
    recurring = build_issue(first_seen: (NOW - 90 * 86_400).iso8601, last_seen: (NOW - 300).iso8601)

    assert_equal 1, rule.select([recurring]).size
  end

  test "the window edge is inclusive" do
    edge = build_issue(last_seen: (NOW - 24 * 3600).iso8601)

    assert_equal 1, rule.select([edge]).size
  end

  test "the look-back hours change the window" do
    issue = build_issue(last_seen: (NOW - 5 * 3600).iso8601)

    assert_empty rule(lookback_hours: 4).select([issue])
    assert_equal 1, rule(lookback_hours: 6).select([issue]).size
  end

  test "only the chosen levels are included" do
    issues = [build_issue(id: "1", level: "warning"), build_issue(id: "2", level: "fatal"), build_issue(id: "3", level: "info")]

    assert_equal ["2"], rule.select(issues).map(&:id)
    assert_equal %w[2 1], rule(levels: %w[warning fatal]).select(issues).map(&:id)
  end

  test "the minimum event count is a floor on the issue's count" do
    issues = [build_issue(id: "1", count: 1), build_issue(id: "2", count: 3)]

    assert_equal %w[2], rule(minimum_event_count: 2).select(issues).map(&:id)
    assert_equal 2, rule(minimum_event_count: 1).select(issues).size
  end

  test "a project allow-list keeps only those projects, an empty one keeps all" do
    issues = [build_issue(id: "1", project_slug: "web"), build_issue(id: "2", project_slug: "billing")]

    assert_equal ["2"], rule(project_slugs: ["billing"]).select(issues).map(&:id)
    assert_equal 2, rule(project_slugs: []).select(issues).size
  end

  test "order is level first, then count, then last seen, all most important first" do
    issues = [
      build_issue(id: "11", level: "error", count: 2, last_seen: (NOW - 60).iso8601),
      build_issue(id: "12", level: "error", count: 50, last_seen: (NOW - 7200).iso8601),
      build_issue(id: "13", level: "error", count: 50, last_seen: (NOW - 120).iso8601),
      build_issue(id: "14", level: "fatal", count: 1, last_seen: (NOW - 9000).iso8601),
      build_issue(id: "15", level: "warning", count: 900)
    ]

    sorted = rule(levels: %w[fatal error warning]).select(issues).map(&:id)

    assert_equal %w[14 13 12 11 15], sorted
  end

  test "an issue with a level the plugin does not know is left out" do
    assert_empty rule(levels: %w[error]).select([build_issue(level: "catastrophe")])
  end
end
