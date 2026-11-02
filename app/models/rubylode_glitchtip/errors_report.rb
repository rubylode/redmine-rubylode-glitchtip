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

module RubylodeGlitchtip
  # What the block shows: GlitchTip's recent issues put through the attention rule, limited to the configured number of
  # rows, with a summary line, or a "status unavailable" report when GlitchTip cannot be asked. GlitchTip's answer is
  # cached (the answer for the cache seconds, a failure for the failure seconds); the rule runs on every report, so the
  # look-back window always ends now.
  class ErrorsReport
    Report = Struct.new(:issues, :hidden_count, :total_issue_count, :total_event_count, :summary, :unavailable, :failure_reason) do
      alias_method :unavailable?, :unavailable

      def summary_state
        return :unavailable if unavailable?

        total_issue_count.zero? ? :clear : :needs_attention
      end
    end

    class << self
      attr_writer :cache

      def cache
        @cache ||= Rails.cache
      end

      def cache_key_for(base_url, organization_slug, lookback_hours = 24)
        "rubylode_glitchtip/issues/#{Digest::SHA256.hexdigest([base_url, organization_slug, lookback_hours].join('|'))[0, 16]}"
      end

      def current(configuration = Configuration.current)
        now = Time.current
        new(rule: AttentionRule.new(now: now, lookback_hours: configuration.lookback_hours,
                                    minimum_event_count: configuration.minimum_event_count,
                                    levels: configuration.levels, project_slugs: configuration.project_allow_list),
            maximum_rows: configuration.maximum_rows,
            fetch_issues: -> { GlitchtipClient.from_configuration(configuration, now: now).call },
            cache: cache,
            cache_key: cache_key_for(configuration.base_url, configuration.organization_slug, configuration.lookback_hours),
            cache_seconds: configuration.cache_seconds,
            failure_seconds: configuration.failure_cache_seconds)
      end
    end

    def initialize(rule:, maximum_rows:, fetch_issues:, cache:, cache_key:, cache_seconds: 60, failure_seconds: 30)
      @rule = rule
      @maximum_rows = maximum_rows
      @fetch_issues = fetch_issues
      @cache = cache
      @cache_key = cache_key
      @cache_seconds = cache_seconds
      @failure_seconds = failure_seconds
    end

    def report
      answer = cached_answer
      return unavailable_report(answer["failure"]) if answer.key?("failure")

      needing_attention = @rule.select(answer["issues"].filter_map { |attributes| issue_from(attributes) })
      shown = needing_attention.first(@maximum_rows)
      event_total = needing_attention.sum(&:count)
      Report.new(shown, needing_attention.size - shown.size, needing_attention.size, event_total,
                 summary_for(needing_attention.size, event_total), false, nil)
    end

    private

    def cached_answer
      answer = @cache.read(@cache_key)
      return answer unless answer.nil?

      begin
        answer = { "issues" => @fetch_issues.call }
        @cache.write(@cache_key, answer, expires_in: @cache_seconds) if @cache_seconds.positive?
      rescue GlitchtipClient::Unavailable => error
        answer = { "failure" => error.message }
        @cache.write(@cache_key, answer, expires_in: @failure_seconds) if @failure_seconds.positive?
      end
      answer
    end

    # A cached entry that cannot be read as an issue is skipped, so one bad entry never takes the page down.
    def issue_from(attributes)
      Issue.new(**attributes.to_h.symbolize_keys)
    rescue ArgumentError, TypeError
      nil
    end

    def unavailable_report(reason)
      reason = I18n.t("rubylode_glitchtip.errors.glitchtip_did_not_answer") if reason.to_s.empty?
      Report.new([], 0, 0, 0, I18n.t("rubylode_glitchtip.status.unavailable"), true, reason)
    end

    def summary_for(issue_count, event_count)
      return I18n.t("rubylode_glitchtip.status.clear") if issue_count.zero?

      [I18n.t("rubylode_glitchtip.status.issues_need_attention", count: issue_count),
       I18n.t("rubylode_glitchtip.status.events", count: event_count)].join(", ")
    end
  end
end
