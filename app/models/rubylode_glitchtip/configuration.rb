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
  # The plugin's settings, read with their defaults and clamped to sensible values. The token is not one of them:
  # only the NAME of the environment variable that holds it is a setting.
  class Configuration
    COLUMNS = %w[left right].freeze
    VISIBILITIES = %w[logged_in admins].freeze
    LEVELS = %w[fatal error warning info debug].freeze
    # The token variable must start with GLITCHTIP_, so the settings can never point the plugin at another secret of the
    # server (the secret key base, a database password) and send it to the configured host.
    ENVIRONMENT_VARIABLE_PATTERN = /\AGLITCHTIP_[A-Z0-9_]*\z/
    HOST_PATTERN = /\A[A-Za-z0-9.-]+\z/
    SLUG_PATTERN = /\A[A-Za-z0-9_-]+\z/
    # number setting => [smallest allowed value, largest allowed value or nil]
    NUMBER_LIMITS = {
      "lookback_hours" => [1, nil], "minimum_event_count" => [1, nil], "maximum_rows" => [1, 100],
      "cache_seconds" => [0, nil], "failure_cache_seconds" => [0, nil], "timeout_seconds" => [1, nil]
    }.freeze

    def self.current
      new(Setting.send(:"plugin_#{RedmineRubylodeGlitchtip::PLUGIN_ID}"))
    end

    def initialize(raw_settings = {})
      @settings = RedmineRubylodeGlitchtip::Defaults::SETTINGS.merge((raw_settings || {}).to_h.stringify_keys.compact)
    end

    def base_url
      @settings["base_url"].to_s.strip.delete_suffix("/")
    end

    def organization_slug
      @settings["organization_slug"].to_s.strip
    end

    # The configured name as typed; see token_variable_allowed? before trusting it.
    def token_environment_variable
      name = @settings["token_environment_variable"].to_s.strip
      name.empty? ? RedmineRubylodeGlitchtip::Defaults::SETTINGS["token_environment_variable"] : name
    end

    def token_variable_allowed?
      token_environment_variable.match?(ENVIRONMENT_VARIABLE_PATTERN)
    end

    # The API token, read from the environment only when the variable's name is allowed. A name that is not allowed is
    # never looked up: the token is treated as missing.
    def token
      token_variable_allowed? ? ENV[token_environment_variable].to_s : ""
    end

    # The host of the base URL, or "" when the base URL is empty or unreadable.
    def base_host
      URI.parse(base_url).host.to_s.downcase
    rescue URI::InvalidURIError
      ""
    end

    # The token goes only to these hosts: the base URL's own host, and any hosts the administrator listed.
    def allowed_hosts
      ([base_host] + self.class.list_from(@settings["allowed_hosts"]).map(&:downcase)).reject(&:empty?).uniq
    end

    def allow_plain_http?
      @settings["allow_plain_http"].to_s == "1"
    end

    # https is required, except for a loopback host or when the administrator allowed plain http for an internal network.
    def transport_allowed?
      uri = URI.parse(base_url)
      uri.scheme == "https" || (uri.scheme == "http" && (self.class.loopback_host?(uri.host) || allow_plain_http?))
    rescue URI::InvalidURIError
      false
    end

    def self.loopback_host?(host)
      host = host.to_s.downcase.delete_prefix("[").delete_suffix("]")
      host == "localhost" || host == "::1" || host.match?(/\A127(\.\d{1,3}){3}\z/)
    end

    def lookback_hours = whole_number("lookback_hours")
    def minimum_event_count = whole_number("minimum_event_count")
    def maximum_rows = whole_number("maximum_rows")
    def cache_seconds = whole_number("cache_seconds")
    def failure_cache_seconds = whole_number("failure_cache_seconds")
    def timeout_seconds = whole_number("timeout_seconds")

    def levels
      chosen = self.class.list_from(@settings["levels"]).map(&:downcase) & LEVELS
      chosen.empty? ? RedmineRubylodeGlitchtip::Defaults::SETTINGS["levels"].dup : chosen
    end

    def project_allow_list
      self.class.list_from(@settings["project_allow_list"]).map(&:downcase)
    end

    def block_title
      title = @settings["block_title"].to_s.strip
      title.empty? ? RedmineRubylodeGlitchtip::Defaults::SETTINGS["block_title"] : title
    end

    def visibility
      VISIBILITIES.include?(@settings["visibility"].to_s) ? @settings["visibility"].to_s : "logged_in"
    end

    def show_on_my_page? = flag?("show_on_my_page")
    def show_on_welcome_page? = flag?("show_on_welcome_page")
    def show_on_project_overview? = flag?("show_on_project_overview")
    def show_in_top_menu? = flag?("show_in_top_menu")

    def welcome_page_column = column("welcome_page_column")
    def project_overview_column = column("project_overview_column")

    # The path patterns that draw the block at the end of a page, one per line in the settings.
    def path_patterns
      PathMatcher.patterns_from(@settings["path_patterns"])
    end

    def visible_to?(user)
      return false unless user&.logged?

      visibility == "admins" ? user.admin? : true
    end

    def configured?
      !base_url.empty? && !organization_slug.empty?
    end

    # A list typed in a form: an array of values or one string separated by commas, spaces or lines.
    def self.list_from(value)
      items = value.is_a?(Array) ? value : value.to_s.split(/[\s,]+/)
      items.map { |item| item.to_s.strip }.reject(&:empty?).uniq
    end

    private

    def flag?(key)
      @settings[key].to_s == "1"
    end

    def column(key)
      COLUMNS.include?(@settings[key].to_s) ? @settings[key].to_s : "right"
    end

    def whole_number(key)
      minimum, maximum = NUMBER_LIMITS.fetch(key)
      value = Integer(@settings[key].to_s.strip, 10)
      value = [value, minimum].max
      maximum ? [value, maximum].min : value
    rescue ArgumentError
      Integer(RedmineRubylodeGlitchtip::Defaults::SETTINGS[key], 10)
    end
  end
end
