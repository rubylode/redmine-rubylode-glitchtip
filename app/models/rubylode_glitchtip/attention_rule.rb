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
  # The "needs attention" rule. An issue needs attention when it is
  #   - unresolved (resolved and ignored issues never do),
  #   - last seen inside the look-back window (so a new issue and an old one that came back both count),
  #   - of one of the chosen levels,
  #   - at or above the minimum event count (the issue's total count, as GlitchTip reports it), and
  #   - in the project allow-list, when there is one.
  # The list is ordered by level (fatal first), then by event count (most first), then by last seen (newest first).
  class AttentionRule
    LEVEL_ORDER = %w[fatal error warning info debug sample].freeze

    def initialize(now:, lookback_hours:, minimum_event_count:, levels:, project_slugs: [])
      @window_start = now - (lookback_hours * 3600)
      @minimum_event_count = minimum_event_count
      @levels = levels
      @project_slugs = project_slugs.map(&:downcase)
    end

    def select(issues)
      issues.select { |issue| needs_attention?(issue) }.sort_by { |issue| sort_key(issue) }
    end

    def needs_attention?(issue)
      issue.status == "unresolved" &&
        issue.last_seen >= @window_start &&
        @levels.include?(issue.level) &&
        LEVEL_ORDER.include?(issue.level) &&
        issue.count >= @minimum_event_count &&
        (@project_slugs.empty? || @project_slugs.include?(issue.project_slug.downcase))
    end

    private

    def sort_key(issue)
      [LEVEL_ORDER.index(issue.level), -issue.count, -issue.last_seen.to_f]
    end
  end
end
