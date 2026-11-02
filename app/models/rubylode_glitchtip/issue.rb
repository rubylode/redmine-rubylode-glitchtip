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
  # One GlitchTip issue, reduced to what the block shows. Nothing in it is trusted: titles and culprits are free text
  # from whatever raised the error, so views must escape them (ERB does by default).
  class Issue
    ATTRIBUTES = %i[id short_id title culprit level count first_seen last_seen status project_slug project_name].freeze
    ID_PATTERN = /\A\d+\z/

    attr_reader(*ATTRIBUTES)

    # Reads one item of GlitchTip's issues list. Returns nil for anything that is not an issue.
    def self.from_api(item)
      return nil unless item.is_a?(Hash)

      project = item["project"].is_a?(Hash) ? item["project"] : {}
      new(id: item["id"], short_id: item["shortId"], title: item["title"], culprit: item["culprit"], level: item["level"],
          count: item["count"], first_seen: item["firstSeen"], last_seen: item["lastSeen"], status: item["status"],
          project_slug: project["slug"], project_name: project["name"])
    rescue ArgumentError, TypeError
      nil
    end

    def initialize(id:, level:, count:, last_seen:, status:, short_id: nil, title: nil, culprit: nil, first_seen: nil,
                   project_slug: nil, project_name: nil)
      raise ArgumentError, "issue id must be digits" unless id.to_s.match?(ID_PATTERN)

      @id = id.to_s
      @short_id = short_id.to_s
      @title = title.to_s
      @culprit = culprit.to_s
      @level = level.to_s.downcase
      @count = Integer(count.to_s, 10)
      @first_seen = parse_time(first_seen, required: false)
      @last_seen = parse_time(last_seen, required: true)
      @status = status.to_s
      @project_slug = project_slug.to_s
      @project_name = project_name.to_s.empty? ? project_slug.to_s : project_name.to_s
    end

    def to_h
      ATTRIBUTES.to_h do |attribute|
        value = public_send(attribute)
        [attribute, value.is_a?(Time) ? value.iso8601 : value]
      end
    end

    def ==(other)
      other.is_a?(Issue) && other.to_h == to_h
    end

    private

    def parse_time(value, required:)
      return nil if value.nil? && !required

      Time.iso8601(value.to_s)
    end
  end
end
