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

class RubylodeGlitchtip::StatusWidgetTest < ActiveSupport::TestCase
  include RubylodeGlitchtipTestHelpers

  # Stands in for RubylodeStatus::Registry and keeps what it was given.
  class FakeRegistry
    attr_reader :registrations

    def initialize
      @registrations = []
    end

    def register(**arguments)
      @registrations << arguments
    end
  end

  setup do
    use_memory_cache
    configure_plugin
    @now = Time.now.utc
  end

  teardown do
    restore_cache
  end

  def recent_issue(overrides = {})
    issue_hash({ first_seen: (@now - 3600).iso8601, last_seen: (@now - 300).iso8601 }.merge(overrides))
  end

  def widget_data
    RubylodeGlitchtip::StatusWidget.data
  end

  test "nothing needing attention is ok, with the owner's one-line summary and no items" do
    publish_issues([])

    assert_equal "ok", widget_data[:state]
    assert_equal "No errors need a look", widget_data[:summary]
    assert_empty widget_data[:items]
  end

  test "issues needing attention make a warning that counts them" do
    publish_issues([recent_issue(id: "1"), recent_issue(id: "2"), recent_issue(id: "3")])

    assert_equal "warning", widget_data[:state]
    assert_equal "3 errors need a look", widget_data[:summary]
  end

  test "one issue needing attention is worded in the singular" do
    publish_issues([recent_issue])

    assert_equal "1 error needs a look", widget_data[:summary]
  end

  test "an item has a name, a state and the level, count and last seen as detail" do
    publish_issues([recent_issue(title: "Boom in checkout", level: "fatal", count: 12)])
    item = widget_data[:items].first

    assert_equal "Boom in checkout", item[:name]
    assert_equal "warning", item[:state]
    assert_equal "Fatal, 12 events, last seen 5 minutes ago", item[:detail]
  end

  test "an issue without a title is named by its short id" do
    publish_issues([recent_issue(title: "", short_id: "WEB-9")])

    assert_equal "WEB-9", widget_data[:items].first[:name]
  end

  test "items stop at the maximum rows while the summary counts every issue" do
    configure_plugin("maximum_rows" => "2")
    publish_issues((1..5).map { |number| recent_issue(id: number.to_s) })
    data = widget_data

    assert_equal 2, data[:items].size
    assert_equal "5 errors need a look", data[:summary]
    assert_equal 3, data[:hidden_count]
  end

  test "a GlitchTip that does not answer is down" do
    publish_failure("GlitchTip answered 500")

    assert_equal "down", widget_data[:state]
    assert_equal "GlitchTip is not answering", widget_data[:summary]
    assert_empty widget_data[:items]
  end

  test "a plugin that is not set up is unknown" do
    configure_plugin("base_url" => "")

    assert_equal "unknown", widget_data[:state]
    assert_equal "GlitchTip is not set up yet", widget_data[:summary]
  end

  test "the summary is one line" do
    publish_issues([recent_issue])

    refute_match(/\n/, widget_data[:summary])
  end

  test "registering gives the registry the key, the page, the partial and callables for title, data and visibility" do
    registry = FakeRegistry.new
    configure_plugin("block_title" => "Production errors", "visibility" => "admins")
    publish_issues([])

    assert RubylodeGlitchtip::StatusWidget.register(registry)
    registration = registry.registrations.first

    assert_equal "glitchtip", registration[:key]
    assert_equal "/status/glitchtip", registration[:path]
    assert_equal "rubylode_glitchtip/status", registration[:partial]
    assert_equal "Production errors", registration[:title].call
    assert_equal "admins", registration[:visibility].call
    assert_equal "ok", registration[:data].call[:state]
  end

  test "the title and visibility are read each time, so a changed setting shows without a restart" do
    registry = FakeRegistry.new
    RubylodeGlitchtip::StatusWidget.register(registry)
    registration = registry.registrations.first

    configure_plugin("block_title" => "Renamed")

    assert_equal "Renamed", registration[:title].call
  end

  test "nothing is registered, and nothing fails, when the Status plugin is not there" do
    without_status_registry do
      refute RubylodeGlitchtip::StatusWidget.register
    end
  end

  test "with the real registry mounted, the widget is registered at boot and draws" do
    skip "the Status plugin is not mounted next to this plugin" unless defined?(::RubylodeStatus::Registry)

    widget = ::RubylodeStatus::Registry.find("glitchtip")

    assert widget, "the widget must be registered after boot"
    assert_equal "/status/glitchtip", widget.path
  end

  private

  # Takes the registry constant away for the length of the block, when the Status plugin is mounted.
  def without_status_registry
    return yield unless defined?(::RubylodeStatus::Registry)

    registry = ::RubylodeStatus::Registry
    ::RubylodeStatus.send(:remove_const, :Registry)
    yield
  ensure
    ::RubylodeStatus.const_set(:Registry, registry) if registry
  end
end
