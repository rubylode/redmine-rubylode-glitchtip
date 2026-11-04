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

# What 2.0.0 renamed keeps answering for one release.
class RubylodeGlitchtip::OldNamesTest < ActionView::TestCase
  include RubylodeGlitchtipTestHelpers

  fixtures :users, :email_addresses

  setup do
    use_memory_cache
    configure_plugin
    now = Time.now.utc
    publish_issues([issue_hash(first_seen: (now - 3600).iso8601, last_seen: (now - 300).iso8601)])
    User.current = User.find(2)
  end

  teardown do
    restore_cache
    User.current = nil
  end

  test "the partial called errors draws the same block as the partial called status" do
    old_name = render(partial: "rubylode_glitchtip/errors")
    new_name = render(partial: "rubylode_glitchtip/status")

    assert_includes old_name, "1 issue needs attention, 5 events"
    assert_equal new_name.strip, old_name.strip
  end

  test "the old partial passes its locals on" do
    html = render(partial: "rubylode_glitchtip/errors", locals: { title: "Production errors", compact: true })

    assert_includes html, "Production errors"
    assert_includes html, "is-compact"
  end
end
