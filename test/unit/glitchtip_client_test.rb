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

class RubylodeGlitchtip::GlitchtipClientTest < ActiveSupport::TestCase
  include RubylodeGlitchtipTestHelpers

  TOKEN = "sample-token-DO-NOT-LEAK-7f3a91".freeze

  def api_item(id, last_seen: NOW - 600, level: "error", status: "unresolved")
    { "id" => id.to_s, "shortId" => "W-#{id}", "title" => "Title #{id}", "level" => level, "count" => "3", "status" => status,
      "firstSeen" => (NOW - 7200).iso8601, "lastSeen" => last_seen.iso8601, "project" => { "slug" => "web", "name" => "Web" } }
  end

  def client(pages:, requests: [], token: TOKEN, lookback_hours: 24)
    pages = pages.dup
    http_client = lambda do |url, sent_token|
      requests << [url, sent_token]
      pages.shift || [200, "[]", nil]
    end
    RubylodeGlitchtip::GlitchtipClient.new(base_url: BASE_URL, organization_slug: ORGANIZATION, token: token, now: NOW,
                                           lookback_hours: lookback_hours, http_client: http_client,
                                           token_environment_variable: "GLITCHTIP_API_TOKEN")
  end

  test "it asks the organization's issues endpoint with the token as a bearer token" do
    requests = []
    client(pages: [[200, JSON.generate([api_item(1)]), nil]], requests: requests).call

    url, sent_token = requests.first
    assert_equal TOKEN, sent_token
    assert url.start_with?("#{BASE_URL}/api/0/organizations/#{ORGANIZATION}/issues/?")
    assert_includes url, "sort=-last_seen"
    refute_includes url, TOKEN
  end

  test "it returns issues as plain hashes" do
    result = client(pages: [[200, JSON.generate([api_item(1), api_item(2)]), nil]]).call

    assert_equal %w[1 2], result.map { |issue| issue[:id] }
    assert_equal "web", result.first[:project_slug]
    assert_equal 3, result.first[:count]
  end

  test "it follows the next-page cursor and stops when a page has run out of the window" do
    requests = []
    link = %(<https://x/?cursor=0:100:0>; rel="previous"; results="false"; cursor="0:100:1", <https://x/?cursor=0:100:0>; rel="next"; results="true"; cursor="0:100:0")
    pages = [[200, JSON.generate([api_item(1)]), link],
             [200, JSON.generate([api_item(2), api_item(3, last_seen: NOW - 50 * 3600)]), link],
             [200, JSON.generate([api_item(4)]), nil]]

    result = client(pages: pages, requests: requests).call

    assert_equal %w[1 2], result.map { |issue| issue[:id] }, "the issue outside the window is dropped"
    assert_equal 2, requests.size, "no third page: the second ended outside the window"
    assert_includes requests.last.first, "cursor=0%3A100%3A0"
  end

  test "it stops when the next link says there are no more results" do
    requests = []
    link = %(<https://x/>; rel="next"; results="false"; cursor="0:200:0")
    client(pages: [[200, JSON.generate([api_item(1)]), link]], requests: requests).call

    assert_equal 1, requests.size
  end

  test "it never asks for more than the page limit" do
    requests = []
    link = %(<https://x/>; rel="next"; results="true"; cursor="0:100:0")
    pages = Array.new(20) { [200, JSON.generate([api_item(1)]), link] }

    client(pages: pages, requests: requests).call

    assert_equal RubylodeGlitchtip::GlitchtipClient::MAX_PAGES, requests.size
  end

  test "items that are not issues are skipped" do
    result = client(pages: [[200, JSON.generate([api_item(1), { "nonsense" => true }, "text"]), nil]]).call

    assert_equal %w[1], result.map { |issue| issue[:id] }
  end

  test "the token is not sent to a host that is not on the list, nor over plain http" do
    [["https://other.example.com", false], ["http://glitchtip.example.com", false]].each do |base_url, allow_plain_http|
      requests = []
      http_client = ->(url, token) { requests << [url, token]; [200, "[]", nil] }
      refused = RubylodeGlitchtip::GlitchtipClient.new(base_url: base_url, organization_slug: ORGANIZATION, token: TOKEN, now: NOW,
                                                       lookback_hours: 24, allowed_hosts: ["glitchtip.example.com"],
                                                       allow_plain_http: allow_plain_http, http_client: http_client)

      error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { refused.call }

      assert_empty requests, base_url
      refute_includes error.message, TOKEN
    end
  end

  test "plain http is fine to a loopback host, and to any listed host when allowed" do
    ok = ->(*) { [200, "[]", nil] }
    loopback = RubylodeGlitchtip::GlitchtipClient.new(base_url: "http://127.0.0.1:9100", organization_slug: ORGANIZATION, token: TOKEN,
                                                      now: NOW, lookback_hours: 24, http_client: ok)
    internal = RubylodeGlitchtip::GlitchtipClient.new(base_url: "http://glitchtip.internal", organization_slug: ORGANIZATION, token: TOKEN,
                                                      now: NOW, lookback_hours: 24, allow_plain_http: true, http_client: ok)

    assert_equal [], loopback.call
    assert_equal [], internal.call
  end

  test "a redirect answer is unavailable and is not followed" do
    requests = []
    http_client = ->(url, _token) { requests << url; [302, "", nil] }
    redirected = RubylodeGlitchtip::GlitchtipClient.new(base_url: BASE_URL, organization_slug: ORGANIZATION, token: TOKEN, now: NOW,
                                                        lookback_hours: 24, http_client: http_client)

    assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { redirected.call }
    assert_equal 1, requests.size
  end

  test "a variable name that is not allowed means no request at all" do
    requests = []
    http_client = ->(*) { requests << 1; [200, "[]", nil] }
    refused = RubylodeGlitchtip::GlitchtipClient.new(base_url: BASE_URL, organization_slug: ORGANIZATION, token: TOKEN, now: NOW,
                                                     lookback_hours: 24, token_variable_allowed: false, http_client: http_client)

    assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { refused.call }
    assert_empty requests
  end

  test "a missing token is unavailable, names the variable and asks nothing" do
    requests = []
    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { client(pages: [], requests: requests, token: "").call }

    assert_includes error.message, "GLITCHTIP_API_TOKEN"
    assert_empty requests
  end

  test "an answer other than 200 is unavailable and shows the status" do
    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { client(pages: [[401, "no", nil]]).call }

    assert_includes error.message, "401"
  end

  test "an answer that is not a list of issues is unavailable" do
    ["not json", JSON.generate("detail" => "oops"), ""].each do |body|
      assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { client(pages: [[200, body, nil]]).call }
    end
  end

  test "a network error is unavailable and names only its class" do
    http_client = ->(*) { raise Errno::ECONNREFUSED, "connect to #{TOKEN}" }
    failing = RubylodeGlitchtip::GlitchtipClient.new(base_url: BASE_URL, organization_slug: ORGANIZATION, token: TOKEN, now: NOW,
                                                     lookback_hours: 24, http_client: http_client)

    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { failing.call }

    assert_includes error.message, "Errno::ECONNREFUSED"
    refute_includes error.message, TOKEN
  end

  test "an error carrying the token in its own message is scrubbed" do
    http_client = ->(*) { raise RubylodeGlitchtip::GlitchtipClient::Unavailable, "boom #{TOKEN}" }
    failing = RubylodeGlitchtip::GlitchtipClient.new(base_url: BASE_URL, organization_slug: ORGANIZATION, token: TOKEN, now: NOW,
                                                     lookback_hours: 24, http_client: http_client)

    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { failing.call }

    refute_includes error.message, TOKEN
  end

  test "a body that echoes the token never reaches the message" do
    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { client(pages: [[500, "bad #{TOKEN}", nil]]).call }

    refute_includes error.message, TOKEN
  end
end
