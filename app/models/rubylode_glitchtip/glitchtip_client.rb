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

require "net/http"
require "json"

module RubylodeGlitchtip
  # Asks GlitchTip's Sentry-compatible API for the organization's issues (GET /api/0/organizations/{slug}/issues/),
  # newest first, and stops paging once the issues are older than the look-back window. The API token is sent as a bearer
  # token and held only in memory for the request: it is not logged, and it is scrubbed from every error message.
  class GlitchtipClient
    class Unavailable < StandardError; end

    PAGE_SIZE = 100
    MAX_PAGES = 5

    def self.from_configuration(configuration, now: Time.current)
      new(base_url: configuration.base_url,
          organization_slug: configuration.organization_slug,
          token: configuration.token,
          token_variable_allowed: configuration.token_variable_allowed?,
          allowed_hosts: configuration.allowed_hosts,
          allow_plain_http: configuration.allow_plain_http?,
          timeout_seconds: configuration.timeout_seconds,
          lookback_hours: configuration.lookback_hours,
          token_environment_variable: configuration.token_environment_variable,
          now: now)
    end

    def initialize(base_url:, organization_slug:, token:, lookback_hours:, now: Time.current, timeout_seconds: 2,
                   token_environment_variable: nil, token_variable_allowed: true, allowed_hosts: nil, allow_plain_http: false,
                   http_client: nil)
      @base_url = base_url
      @organization_slug = organization_slug
      @token = token
      @window_start = now - (lookback_hours * 3600)
      @timeout_seconds = timeout_seconds
      @token_environment_variable = token_environment_variable
      @token_variable_allowed = token_variable_allowed
      @allow_plain_http = allow_plain_http
      @allowed_hosts = (allowed_hosts || [URI.parse(base_url).host]).map { |host| host.to_s.downcase }
      @http_client = http_client || method(:fetch_over_http)
    end

    # Returns the issues seen inside the window as plain hashes (Issue#to_h), whatever their status or level.
    def call
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.token_variable_not_allowed") unless @token_variable_allowed
      raise Unavailable, token_missing_message if @token.empty?

      issues = []
      cursor = nil
      MAX_PAGES.times do
        page_issues, cursor = fetch_page(cursor)
        issues.concat(page_issues)
        break if cursor.nil? || page_issues.empty? || page_issues.last.last_seen < @window_start
      end
      issues.select { |issue| issue.last_seen >= @window_start }.map(&:to_h)
    rescue Unavailable => error
      raise Unavailable, scrub(error.message)
    rescue StandardError => error
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.glitchtip_unreachable", error_class: error.class)
    end

    private

    def fetch_page(cursor)
      url = page_url(cursor)
      check_destination(url)
      status, body, link_header = @http_client.call(url, @token)
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.glitchtip_redirected") if (300..399).cover?(status)
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.glitchtip_status", status: status) unless status == 200

      [parse_issues(body), next_cursor(link_header)]
    end

    # The token is sent only over https (or plain http to a loopback host, or when the administrator allowed it), and
    # only to a host on the list. Checked before every request, so nothing built from an answer can redirect the token.
    def check_destination(url)
      uri = URI.parse(url)
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.host_not_allowed") unless @allowed_hosts.include?(uri.host.to_s.downcase)

      secure = uri.scheme == "https" || (uri.scheme == "http" && (Configuration.loopback_host?(uri.host) || @allow_plain_http))
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.transport_not_allowed") unless secure
    end

    def parse_issues(body)
      items = JSON.parse(body.to_s)
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.glitchtip_unreadable") unless items.is_a?(Array)

      items.filter_map { |item| Issue.from_api(item) }
    rescue JSON::ParserError
      raise Unavailable, I18n.t("rubylode_glitchtip.errors.glitchtip_unreadable")
    end

    def page_url(cursor)
      parameters = { query: "is:unresolved", sort: "-last_seen", limit: PAGE_SIZE }
      parameters[:cursor] = cursor if cursor
      "#{@base_url}/api/0/organizations/#{ERB::Util.url_encode(@organization_slug)}/issues/?#{URI.encode_www_form(parameters)}"
    end

    # GlitchTip pages like Sentry: a Link header with rel="next", results="true|false" and the cursor to send back.
    def next_cursor(link_header)
      link_header.to_s.split(/,\s*(?=<)/).each do |link|
        next unless link.include?('rel="next"') && link.include?('results="true"')

        cursor = link[/cursor="([^"]+)"/, 1]
        return cursor if cursor
      end
      nil
    end

    def token_missing_message
      base = I18n.t("rubylode_glitchtip.errors.token_missing")
      @token_environment_variable ? "#{base} (#{@token_environment_variable})" : base
    end

    def scrub(message)
      @token.empty? ? message : message.gsub(@token, "[filtered]")
    end

    def fetch_over_http(url, token)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                     open_timeout: @timeout_seconds, read_timeout: @timeout_seconds) do |http|
        http.request(request)
      end
      [response.code.to_i, response.body, response["Link"]]
    end
  end
end
