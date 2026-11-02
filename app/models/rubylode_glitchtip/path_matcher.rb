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
  # Decides whether the block is drawn at the end of a page, from the path patterns in the settings.
  #   - A pattern is a path such as /issues or /projects/*/issues. A star matches any run of characters, slashes included;
  #     everything else is literal.
  #   - The query string and the fragment are ignored, in the pattern and in the path, and so is a trailing slash.
  #   - Settings, administration, sign-in and account pages never match unless a pattern names them: a pattern has to
  #     begin with the page's own path (/admin/*, /login), so /* or /*/edit do not reach them.
  #   - The block's own page never matches, so it is not drawn twice.
  class PathMatcher
    PROTECTED_PATHS = %w[/settings /admin /login /logout /account].freeze
    OWN_PAGE = "/glitchtip_errors".freeze

    def self.patterns_from(text)
      text.to_s.lines.map(&:strip).reject(&:empty?)
    end

    def self.normalize(path)
      cleaned = path.to_s.split(/[?#]/, 2).first.to_s.strip
      cleaned.length > 1 ? cleaned.chomp("/") : cleaned
    end

    def initialize(patterns)
      @patterns = patterns.map { |pattern| self.class.normalize(pattern) }.reject(&:empty?)
    end

    def match?(path)
      path = self.class.normalize(path)
      return false if path == OWN_PAGE || @patterns.empty?

      protected_path = PROTECTED_PATHS.find { |prefix| path == prefix || path.start_with?("#{prefix}/") }
      @patterns.any? do |pattern|
        (protected_path.nil? || pattern.start_with?(protected_path)) && regular_expression_for(pattern).match?(path)
      end
    end

    private

    def regular_expression_for(pattern)
      Regexp.new("\\A#{pattern.split('*', -1).map { |part| Regexp.escape(part) }.join('.*')}\\z")
    end
  end
end
