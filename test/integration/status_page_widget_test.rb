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

# The block on the Status plugin's page. Runs only while the Status plugin is mounted next to this plugin (bin/test does that
# when its checkout is beside this one).
class RubylodeGlitchtip::StatusPageWidgetTest < Redmine::IntegrationTest
  include RubylodeGlitchtipTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles

  setup do
    skip "the Status plugin is not mounted next to this plugin" unless defined?(::RubylodeStatus::Registry)
    use_memory_cache
    configure_plugin
    now = Time.now.utc
    publish_issues([issue_hash(title: "Boom", first_seen: (now - 3600).iso8601, last_seen: (now - 300).iso8601)])
  end

  teardown do
    restore_cache if @original_cache
  end

  test "the Status page shows the block with its summary and the table of issues" do
    log_user("jsmith", "jsmith")
    get "/status"

    assert_response :success
    assert_select "a[href=?]", "/status/glitchtip", text: "Errors"
    assert_select "body", text: /1 error needs a look/
    assert_select ".rubylode-glitchtip-errors-table", text: /Boom/
  end

  test "a person who may not see the block does not get it on the Status page" do
    configure_plugin("visibility" => "admins")
    log_user("jsmith", "jsmith")
    get "/status"

    assert_select "a[href=?]", "/status/glitchtip", 0
  end
end
