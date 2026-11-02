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

require "socket"
require "json"
require "time"
require "uri"

# A small stand-in for GlitchTip's issues API, for the tests and the demo. It answers
# GET /api/0/organizations/{organization}/issues/ in GlitchTip's shape (a JSON list, counts as strings, a Link header for
# paging) and wants "Authorization: Bearer <token>". Everything in it is made up.
class FakeGlitchtipServer
  # Written as seconds ago, so the issues are recent whenever the server is asked.
  ISSUES = [
    { id: 1, short_id: "WEB-41", title: "NoMethodError: undefined method 'total' for nil", culprit: "app/models/cart.rb in total",
      level: "error", count: 128, status: "unresolved", first_seen_ago: 5 * 86_400, last_seen_ago: 240, project: %w[web Storefront] },
    { id: 2, short_id: "API-9", title: "PG::ConnectionBad: connection pool exhausted", culprit: "db/pool.rb in checkout",
      level: "fatal", count: 14, status: "unresolved", first_seen_ago: 3600, last_seen_ago: 120, project: %w[api Public\ API] },
    { id: 3, short_id: "WEB-52", title: "Timeout::Error: execution expired", culprit: "lib/payment_gateway.rb in charge",
      level: "error", count: 6, status: "unresolved", first_seen_ago: 2 * 3600, last_seen_ago: 3000, project: %w[web Storefront] },
    { id: 4, short_id: "WORKER-3", title: "Redis::TimeoutError", culprit: "jobs/mailer_job.rb in perform",
      level: "error", count: 52, status: "unresolved", first_seen_ago: 40 * 86_400, last_seen_ago: 7200, project: %w[worker Background\ worker] },
    { id: 5, short_id: "WEB-60", title: "Deprecation: Hash#except will change", culprit: "app/helpers/format_helper.rb",
      level: "warning", count: 900, status: "unresolved", first_seen_ago: 86_400, last_seen_ago: 600, project: %w[web Storefront] },
    { id: 6, short_id: "API-2", title: "ActiveRecord::RecordNotFound", culprit: "app/controllers/orders_controller.rb",
      level: "error", count: 33, status: "resolved", first_seen_ago: 9 * 86_400, last_seen_ago: 900, project: %w[api Public\ API] },
    { id: 7, short_id: "WEB-12", title: "ActionController::InvalidAuthenticityToken", culprit: "app/controllers/sessions_controller.rb",
      level: "error", count: 71, status: "ignored", first_seen_ago: 20 * 86_400, last_seen_ago: 1800, project: %w[web Storefront] },
    { id: 8, short_id: "API-1", title: "Errno::ENOENT: No such file or directory @ rb_sysopen", culprit: "lib/exporter.rb",
      level: "error", count: 8, status: "unresolved", first_seen_ago: 70 * 86_400, last_seen_ago: 3 * 86_400, project: %w[api Public\ API] }
  ].freeze

  HOSTILE_TITLE = %(<script>alert("owned")</script> <img src=x onerror=alert(1)> &amp; "quotes").freeze

  SCENARIOS = %w[several none unavailable hostile redirect].freeze

  attr_reader :port, :request_count, :authorizations
  attr_accessor :scenario, :redirect_to

  def initialize(token:, organization: "demo-org", port: 0, scenario: "several", host: "127.0.0.1")
    @token = token
    @organization = organization
    @host = host
    @requested_port = port
    @scenario = scenario
    @request_count = 0
    @authorizations = []
  end

  def start
    @server = TCPServer.new(@host, @requested_port)
    @port = @server.addr[1]
    @thread = Thread.new { accept_loop }
    self
  end

  def stop
    @server&.close
    @thread&.join(2)
  end

  def base_url
    "http://#{@host}:#{@port}"
  end

  # The list the issues endpoint would answer, before paging.
  def issues
    case scenario
    when "none" then []
    when "hostile" then [issue_json(ISSUES[0].merge(title: HOSTILE_TITLE, culprit: "<b>culprit</b>", project: ["web", "<i>Store</i>"]))]
    else ISSUES.map { |attributes| issue_json(attributes) }
    end
  end

  private

  def issue_json(attributes)
    now = Time.now.utc
    { "id" => attributes[:id].to_s, "shortId" => attributes[:short_id], "title" => attributes[:title], "culprit" => attributes[:culprit],
      "level" => attributes[:level], "count" => attributes[:count].to_s, "status" => attributes[:status], "type" => "error",
      "metadata" => {}, "numComments" => 0, "userCount" => 0, "permalink" => "Not implemented",
      "firstSeen" => (now - attributes[:first_seen_ago]).iso8601(6), "lastSeen" => (now - attributes[:last_seen_ago]).iso8601(6),
      "project" => { "id" => "1", "slug" => attributes[:project][0], "name" => attributes[:project][1], "platform" => "ruby" } }
  end

  def accept_loop
    loop do
      client = @server.accept
      Thread.new(client) { |connection| handle(connection) }
    rescue IOError, Errno::EBADF
      break
    end
  end

  def handle(client)
    request_line = client.gets.to_s
    headers = {}
    while (line = client.gets) && line != "\r\n"
      name, value = line.split(":", 2)
      headers[name.downcase] = value.to_s.strip
    end
    method, target = request_line.split(" ")
    status, body, extra_headers = respond(method, target.to_s, headers)
    head = extra_headers.map { |name, value| "#{name}: #{value}\r\n" }.join
    client.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n#{head}Connection: close\r\n\r\n#{body}")
  rescue StandardError
    nil
  ensure
    client.close
  end

  def respond(method, target, headers)
    path, query = target.split("?", 2)
    if method == "POST" && path.start_with?("/__scenario/")
      name = path.delete_prefix("/__scenario/")
      return ["404 Not Found", "unknown scenario\n", {}] unless SCENARIOS.include?(name)

      self.scenario = name
      ["200 OK", "scenario #{name}\n", {}]
    elsif path == "/__requests"
      ["200 OK", "#{request_count}\n", {}]
    elsif path == "/api/0/organizations/#{@organization}/issues/"
      issues_response(headers, URI.decode_www_form(query.to_s).to_h)
    else
      ["404 Not Found", JSON.generate("detail" => "Not found."), {}]
    end
  end

  def issues_response(headers, parameters)
    @request_count += 1
    @authorizations << headers["authorization"]
    return ["503 Service Unavailable", JSON.generate("detail" => "glitchtip is unwell"), {}] if scenario == "unavailable"
    return ["302 Found", "", { "Location" => redirect_to.to_s }] if scenario == "redirect"
    return ["401 Unauthorized", JSON.generate("detail" => "Authentication credentials were not provided."), {}] unless token_accepted?(headers["authorization"])

    limit = (parameters["limit"] || 100).to_i
    offset = parameters["cursor"].to_s.split(":")[1].to_i
    all = issues.sort_by { |issue| issue["lastSeen"] }.reverse
    page = all[offset, limit] || []
    more = offset + limit < all.size
    link = %(<#{base_url}/>; rel="previous"; results="false"; cursor="0:#{[offset - limit, 0].max}:1", ) +
           %(<#{base_url}/>; rel="next"; results="#{more}"; cursor="0:#{offset + limit}:0")
    ["200 OK", JSON.generate(page), { "Link" => link }]
  end

  def token_accepted?(authorization)
    authorization.to_s == "Bearer #{@token}"
  end
end

if $PROGRAM_NAME == __FILE__
  server = FakeGlitchtipServer.new(token: ENV.fetch("FAKE_GLITCHTIP_TOKEN"), port: ENV.fetch("FAKE_GLITCHTIP_PORT", "9100").to_i,
                                   organization: ENV.fetch("FAKE_GLITCHTIP_ORGANIZATION", "demo-org"), host: "0.0.0.0",
                                   scenario: ENV.fetch("FAKE_GLITCHTIP_SCENARIO", "several")).start
  puts "Fake GlitchTip on port #{server.port}, scenario #{server.scenario}"
  $stdout.flush
  sleep
end
