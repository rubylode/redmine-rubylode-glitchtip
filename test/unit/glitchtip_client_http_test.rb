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

# The client against the fake GlitchTip over a real socket: the headers it sends and what it refuses to do.
class RubylodeGlitchtip::GlitchtipClientHttpTest < ActiveSupport::TestCase
  TOKEN = "sample-token-DO-NOT-LEAK-7f3a91".freeze

  setup do
    @server = FakeGlitchtipServer.new(token: TOKEN, organization: "demo-org").start
    @other_server = FakeGlitchtipServer.new(token: TOKEN, organization: "demo-org").start
  end

  teardown do
    @server.stop
    @other_server.stop
    ENV.delete("GLITCHTIP_HTTP_TEST_TOKEN")
    ENV.delete("SECRET_KEY_BASE_HTTP_TEST")
  end

  def configuration(overrides = {})
    RubylodeGlitchtip::Settings.new(
      { "base_url" => @server.base_url, "organization_slug" => "demo-org", "token_environment_variable" => "GLITCHTIP_HTTP_TEST_TOKEN",
        "timeout_seconds" => "2" }.merge(overrides)
    )
  end

  def fetch(configuration)
    RubylodeGlitchtip::GlitchtipClient.from_settings(configuration).call
  end

  test "with the right token the issues come back, and the token went in a bearer header" do
    ENV["GLITCHTIP_HTTP_TEST_TOKEN"] = TOKEN

    result = fetch(configuration)

    assert_equal FakeGlitchtipServer::ISSUES.size - 1, result.size, "the issue last seen three days ago is outside the window"
    assert_equal ["Bearer #{TOKEN}"], @server.authorizations.uniq
  end

  test "a wrong token is unavailable and its value is nowhere in the message" do
    ENV["GLITCHTIP_HTTP_TEST_TOKEN"] = "wrong-token-also-secret-55"

    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { fetch(configuration) }

    assert_includes error.message, "401"
    refute_includes error.message, "wrong-token-also-secret-55"
  end

  test "a redirect to another host is not followed, so that host never sees the token" do
    ENV["GLITCHTIP_HTTP_TEST_TOKEN"] = TOKEN
    @server.scenario = "redirect"
    @server.redirect_to = "#{@other_server.base_url}/api/0/organizations/demo-org/issues/"

    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { fetch(configuration) }

    assert_includes error.message, "redirect"
    assert_equal 0, @other_server.request_count
    assert_empty @other_server.authorizations
  end

  test "SECRET_KEY_BASE and other variables outside the GLITCHTIP_ prefix are never sent" do
    ENV["SECRET_KEY_BASE_HTTP_TEST"] = "super-secret-key-base-value"

    assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) do
      fetch(configuration("token_environment_variable" => "SECRET_KEY_BASE_HTTP_TEST"))
    end
    assert_equal 0, @server.request_count
    assert_empty @server.authorizations
  end

  test "plain http to a host that is not loopback and not allowed sends nothing" do
    ENV["GLITCHTIP_HTTP_TEST_TOKEN"] = TOKEN

    assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) do
      fetch(configuration("base_url" => "http://glitchtip.invalid:#{@server.port}"))
    end
    assert_equal 0, @server.request_count
  end

  test "a down server is unavailable" do
    ENV["GLITCHTIP_HTTP_TEST_TOKEN"] = TOKEN
    @server.scenario = "unavailable"

    error = assert_raises(RubylodeGlitchtip::GlitchtipClient::Unavailable) { fetch(configuration) }

    assert_includes error.message, "503"
  end
end
