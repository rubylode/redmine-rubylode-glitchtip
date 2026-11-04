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
  # What this plugin hands to the Status plugin: the widget contract's data (a state, a one-line summary and a list of
  # items), built from the same report as the block, so GlitchTip is asked once for both. docs/widget-contract.md in the
  # Status plugin describes the contract.
  module StatusWidget
    KEY = "glitchtip".freeze
    PAGE_PATH = "/status/glitchtip".freeze
    PARTIAL = "rubylode_glitchtip/status".freeze

    class << self
      # Registers the widget with the Status plugin's registry and returns true. Without a registry it does nothing and
      # returns false, so the plugin works the same with or without the Status plugin.
      def register(registry = nil)
        registry ||= ::RubylodeStatus::Registry if defined?(::RubylodeStatus::Registry)
        return false if registry.nil?

        registry.register(
          key: KEY,
          title: -> { Settings.current.block_title },
          path: PAGE_PATH,
          data: -> { data },
          partial: PARTIAL,
          visibility: -> { Settings.current.visibility }
        )
        true
      end

      # state: ok (nothing needs attention), warning (something does), down (GlitchTip did not answer) or unknown
      # (the plugin is not set up). Every item is an issue that needs attention. The report rides along as :report for
      # the partial; the Status plugin keeps it out of its JSON.
      def data(settings = Settings.current)
        return not_set_up unless settings.configured?

        report = ErrorsReport.safe_report(settings)
        return { state: "down", summary: t("down"), items: [], report: report } if report.unavailable?
        return { state: "ok", summary: t("ok"), items: [], report: report } if report.total_issue_count.zero?

        { state: "warning", summary: t("warning", count: report.total_issue_count), items: report.issues.map { |issue| item_for(issue) },
          hidden_count: report.hidden_count, report: report }
      end

      private

      def not_set_up
        { state: "unknown", summary: t("not_set_up"), items: [] }
      end

      def item_for(issue)
        { name: issue.title.presence || issue.short_id, state: "warning", detail: detail_for(issue) }
      end

      def detail_for(issue)
        level = I18n.t("rubylode_glitchtip.levels.#{AttentionRule::LEVEL_ORDER.include?(issue.level) ? issue.level : 'unknown'}")
        t("item_detail", level: level, events: I18n.t("rubylode_glitchtip.status.events", count: issue.count),
                         time: time_helper.time_ago_in_words(issue.last_seen))
      end

      def time_helper
        @time_helper ||= Object.new.extend(ActionView::Helpers::DateHelper)
      end

      def t(key, **options)
        I18n.t("rubylode_glitchtip.status_widget.#{key}", **options)
      end
    end
  end
end
