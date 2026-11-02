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

class RubylodeGlitchtip::ErrorsReportTest < ActiveSupport::TestCase
  include RubylodeGlitchtipTestHelpers

  def report_for(issue_hashes, fetch: nil, cache: ActiveSupport::Cache::MemoryStore.new, **options)
    rule = RubylodeGlitchtip::AttentionRule.new(
      **{ now: NOW, lookback_hours: 24, minimum_event_count: 1, levels: %w[error fatal], project_slugs: [] }.merge(options.slice(:levels, :minimum_event_count, :project_slugs))
    )
    RubylodeGlitchtip::ErrorsReport.new(
      rule: rule, maximum_rows: options.fetch(:maximum_rows, 10), cache: cache,
      cache_key: RubylodeGlitchtip::ErrorsReport.cache_key_for(BASE_URL, ORGANIZATION),
      cache_seconds: options.fetch(:cache_seconds, 60), failure_seconds: options.fetch(:failure_seconds, 30),
      fetch_issues: fetch || -> { issue_hashes }
    )
  end

  test "with nothing that needs attention the summary says so" do
    report = report_for([issue_hash(status: "resolved")]).report

    assert_equal "No errors need attention", report.summary
    assert_equal :clear, report.summary_state
    assert_empty report.issues
    refute report.unavailable?
  end

  test "the summary counts issues and events, singular and plural" do
    many = report_for([issue_hash(id: "1", count: 5), issue_hash(id: "2", count: 7)]).report
    one = report_for([issue_hash(id: "1", count: 1)]).report

    assert_equal "2 issues need attention, 12 events", many.summary
    assert_equal :needs_attention, many.summary_state
    assert_equal "1 issue needs attention, 1 event", one.summary
  end

  test "rows are limited but the summary still counts everything that needs attention" do
    hashes = (1..5).map { |number| issue_hash(id: number.to_s, count: number) }

    report = report_for(hashes, maximum_rows: 2).report

    assert_equal 2, report.issues.size
    assert_equal %w[5 4], report.issues.map(&:id)
    assert_equal 3, report.hidden_count
    assert_equal "5 issues need attention, 15 events", report.summary
  end

  test "issues are ordered by the attention rule" do
    report = report_for([issue_hash(id: "1", level: "error", count: 9), issue_hash(id: "2", level: "fatal", count: 1)]).report

    assert_equal %w[2 1], report.issues.map(&:id)
  end

  test "when GlitchTip cannot be asked the report is unavailable with a reason" do
    failing = -> { raise RubylodeGlitchtip::GlitchtipClient::Unavailable, "GlitchTip answered 503" }

    report = report_for([], fetch: failing).report

    assert report.unavailable?
    assert_equal "Status unavailable", report.summary
    assert_equal :unavailable, report.summary_state
    assert_equal "GlitchTip answered 503", report.failure_reason
  end

  test "an answer is cached for the cache seconds" do
    calls = 0
    cache = ActiveSupport::Cache::MemoryStore.new
    counting = -> { calls += 1; [issue_hash] }

    2.times { report_for([], fetch: counting, cache: cache).report }

    assert_equal 1, calls
  end

  test "a failure is cached too, so a dead GlitchTip is left alone" do
    calls = 0
    cache = ActiveSupport::Cache::MemoryStore.new
    failing = -> { calls += 1; raise RubylodeGlitchtip::GlitchtipClient::Unavailable, "down" }

    reports = Array.new(2) { report_for([], fetch: failing, cache: cache).report }

    assert_equal 1, calls
    assert reports.all?(&:unavailable?)
    assert_equal "down", reports.last.failure_reason
  end

  test "with zero cache seconds every report asks again" do
    calls = 0
    cache = ActiveSupport::Cache::MemoryStore.new
    counting = -> { calls += 1; [] }

    2.times { report_for([], fetch: counting, cache: cache, cache_seconds: 0).report }

    assert_equal 2, calls
  end

  test "the cache key depends on the address, the organization and the look-back, and holds no readable address" do
    key = RubylodeGlitchtip::ErrorsReport.cache_key_for(BASE_URL, ORGANIZATION)

    refute_equal key, RubylodeGlitchtip::ErrorsReport.cache_key_for(BASE_URL, "other-org")
    refute_equal key, RubylodeGlitchtip::ErrorsReport.cache_key_for(BASE_URL, ORGANIZATION, 48)
    refute_includes key, "glitchtip.example.com"
  end

  test "a cache that cannot be read or written still gives the report from a live fetch, and logs a warning" do
    calls = 0
    fetch = -> { calls += 1; [issue_hash] }
    report = nil
    log = captured_log { report = report_for([], fetch: fetch, cache: UnwritableCache.new).report }

    refute report.unavailable?
    assert_equal 1, report.total_issue_count
    assert_equal 1, calls
    assert_includes log, "WARN"
    assert_includes log, "Errno::EACCES"
  end

  test "a cache that cannot be written still gives the report from a live fetch" do
    report = nil
    log = captured_log { report = report_for([issue_hash], cache: UnwritableCache.new(read: false)).report }

    refute report.unavailable?
    assert_equal 1, report.total_issue_count
    assert_includes log, "cache write failed"
  end

  test "a failed fetch with a cache that cannot be written is the status unavailable report" do
    failing = -> { raise RubylodeGlitchtip::GlitchtipClient::Unavailable, "GlitchTip answered 503" }
    report = nil
    captured_log { report = report_for([], fetch: failing, cache: UnwritableCache.new).report }

    assert report.unavailable?
    assert_equal "GlitchTip answered 503", report.failure_reason
  end

  test "any error from the cache store is ignored, not only system call errors" do
    cache = Object.new
    def cache.read(*) = raise(TypeError, "incompatible marshal file format")
    def cache.write(*) = raise(IOError, "closed stream")
    report = nil
    captured_log { report = report_for([issue_hash], cache: cache).report }

    refute report.unavailable?
  end

  test "safe_report answers status unavailable and logs the class when building the report raises" do
    configuration = RubylodeGlitchtip::Configuration.current
    report = nil
    log = captured_log do
      replacing_method(RubylodeGlitchtip::ErrorsReport, :current, ->(*) { raise ArgumentError, "boom" }) do
        report = RubylodeGlitchtip::ErrorsReport.safe_report(configuration)
      end
    end

    assert report.unavailable?
    assert_equal "Status unavailable", report.summary
    assert_equal "ArgumentError", report.failure_reason
    assert_includes log, "ArgumentError: boom"
  end
end
