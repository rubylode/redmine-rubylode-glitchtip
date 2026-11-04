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
  # Checks the settings form before it is saved. Returns a list of messages, empty when everything is fine.
  # Empty values are fine where the plugin has a default or the setting is optional. A message never repeats what was
  # typed into the token variable field, so a pasted token cannot come back out through an error.
  class SettingsValidator
    MAXIMUM_PATH_LENGTH = 200
    MAXIMUM_PATHS = 20

    def self.errors_for(raw_settings)
      new(raw_settings).errors
    end

    def initialize(raw_settings)
      @settings = (raw_settings || {}).to_h.stringify_keys
    end

    def errors
      messages = []
      messages << t("base_url_invalid") unless blank_or_web_address?("base_url")
      messages << t("plain_http_not_allowed") if plain_http_refused?
      messages << t("allowed_hosts_invalid") unless allowed_hosts_valid?
      messages << t("organization_slug_invalid") unless blank_or_slug?(@settings["organization_slug"])
      messages << t("environment_variable_invalid") unless environment_variable_valid?
      messages << t("block_title_blank") if @settings.key?("block_title") && @settings["block_title"].to_s.strip.empty?
      messages << t("visibility_invalid") unless visibility_valid?
      messages << t("column_invalid") unless columns_valid?
      messages.concat(matching_page_path_errors)
      messages.concat(level_errors)
      messages.concat(project_errors)
      messages.concat(number_errors)
      messages
    end

    private

    def t(key, **options)
      I18n.t("rubylode_glitchtip.errors.#{key}", **options)
    end

    def blank_or_web_address?(key)
      value = @settings[key].to_s.strip
      return true if value.empty?

      uri = URI.parse(value)
      %w[http https].include?(uri.scheme) && !uri.host.to_s.empty?
    rescue URI::InvalidURIError
      false
    end

    def blank_or_slug?(value)
      value.to_s.strip.empty? || value.to_s.strip.match?(Settings::SLUG_PATTERN)
    end

    # A plain http address needs a loopback host or the "Allow plain http" box.
    def plain_http_refused?
      value = @settings["base_url"].to_s.strip
      return false unless !value.empty? && blank_or_web_address?("base_url")

      uri = URI.parse(value)
      uri.scheme == "http" && !Settings.loopback_host?(uri.host) && @settings["allow_plain_http"].to_s != "1"
    end

    def allowed_hosts_valid?
      Settings.list_from(@settings["allowed_hosts"]).all? { |host| host.match?(Settings::HOST_PATTERN) }
    end

    def environment_variable_valid?
      name = @settings["token_environment_variable"].to_s.strip
      name.empty? || name.match?(Settings::ENVIRONMENT_VARIABLE_PATTERN)
    end

    def visibility_valid?
      !@settings.key?("visibility") || Settings::VISIBILITIES.include?(@settings["visibility"].to_s)
    end

    def columns_valid?
      %w[welcome_page_column project_overview_column].all? do |key|
        !@settings.key?(key) || Settings::COLUMNS.include?(@settings[key].to_s)
      end
    end

    # One message per bad line. A path: it starts with one slash, has no scheme or host, no spaces or
    # control characters, and is not unreasonably long; the list is not unreasonably long either.
    def matching_page_path_errors
      lines = @settings["matching_page_paths"].to_s.lines.map(&:strip)
      messages = []
      lines.each_with_index do |pattern, index|
        next if pattern.empty?

        valid = pattern.start_with?("/") && !pattern.start_with?("//") && !pattern.match?(/[[:space:][:cntrl:]]/) &&
                pattern.length <= MAXIMUM_PATH_LENGTH
        messages << t("matching_page_path_line", line_number: index + 1, maximum: MAXIMUM_PATH_LENGTH) unless valid
      end
      messages << t("matching_page_paths_too_many", maximum: MAXIMUM_PATHS) if lines.reject(&:empty?).size > MAXIMUM_PATHS
      messages
    end

    def level_errors
      return [] unless @settings.key?("levels")

      chosen = Settings.list_from(@settings["levels"])
      return [t("levels_none")] if chosen.empty?

      (chosen - Settings::LEVELS).any? ? [t("levels_unknown")] : []
    end

    def project_errors
      slugs = Settings.list_from(@settings["project_allow_list"])
      slugs.all? { |slug| slug.match?(Settings::SLUG_PATTERN) } ? [] : [t("project_allow_list_invalid")]
    end

    def number_errors
      Settings::NUMBER_LIMITS.filter_map do |key, (minimum, maximum)|
        value = @settings[key].to_s.strip
        next if value.empty?

        valid = value.match?(/\A\d+\z/) && value.to_i >= minimum && (maximum.nil? || value.to_i <= maximum)
        next if valid

        field = I18n.t("rubylode_glitchtip.settings.#{key}.label")
        maximum ? t("number_between", field: field, minimum: minimum, maximum: maximum) : t("number_invalid", field: field, minimum: minimum)
      end
    end
  end
end
