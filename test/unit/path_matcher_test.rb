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

class RubylodeGlitchtip::PathMatcherTest < ActiveSupport::TestCase
  def matcher(*patterns)
    RubylodeGlitchtip::PathMatcher.new(patterns)
  end

  test "an exact path matches itself and nothing longer" do
    assert matcher("/issues").match?("/issues")
    refute matcher("/issues").match?("/issues/12")
    refute matcher("/issues").match?("/projects")
  end

  test "a star matches anything inside one path segment" do
    assert matcher("/projects/*/issues").match?("/projects/ecookbook/issues")
    refute matcher("/projects/*/issues").match?("/projects/a/b/issues")
    refute matcher("/projects/*/issues").match?("/projects/ecookbook/wiki")
    assert matcher("/issues/*").match?("/issues/12")
    refute matcher("/issues/*").match?("/issues/12/edit")
    assert matcher("/issue*").match?("/issues")
    assert matcher("/*").match?("/wiki")
    refute matcher("/*").match?("/wiki/Page")
  end

  test "two stars match anything, slashes included" do
    assert matcher("/projects/**/issues").match?("/projects/a/b/issues")
    assert matcher("/projects/**/issues").match?("/projects/ecookbook/issues")
    assert matcher("/wiki/**").match?("/wiki/Page/History")
    assert matcher("/**").match?("/a/b/c")
    refute matcher("/projects/**/issues").match?("/projects/ecookbook/wiki")
  end

  test "regular expression characters in a pattern are plain characters" do
    assert matcher("/a.b").match?("/a.b")
    refute matcher("/a.b").match?("/axb")
    assert matcher("/a+b(c)").match?("/a+b(c)")
  end

  test "the query string and the fragment are ignored" do
    assert matcher("/issues").match?("/issues?set_filter=1&status_id=o")
    assert matcher("/issues").match?("/issues#top")
    assert matcher("/issues?x=1").match?("/issues"), "a query string in a pattern is ignored as well"
  end

  test "a trailing slash does not matter, in the path or in the pattern" do
    assert matcher("/issues").match?("/issues/")
    assert matcher("/issues/").match?("/issues")
    assert matcher("/").match?("/")
  end

  test "the root path matches only the root pattern, a star, or a pattern that lists it" do
    assert matcher("/").match?("/")
    refute matcher("/issues").match?("/")
    assert matcher("/*").match?("/")
  end

  test "settings, admin, login and account pages never match a wildcard" do
    wildcard = matcher("/*", "/*/edit", "/**", "**")

    %w[/settings /settings/plugin/redmine_rubylode_glitchtip /admin /admin/plugins /login /logout /account/register
       /account/lost_password].each do |path|
      refute wildcard.match?(path), "#{path} must not match"
    end
    assert wildcard.match?("/issues")
  end

  test "a protected page matches when a pattern names it explicitly" do
    assert matcher("/login").match?("/login")
    assert matcher("/admin/*").match?("/admin/plugins")
    assert matcher("/settings/**").match?("/settings/plugin/x")
    refute matcher("/adm*").match?("/admin"), "a shorter prefix with a star is not an explicit listing"
  end

  test "the block's own page never matches, so it is not drawn twice" do
    refute matcher("/*").match?("/status/glitchtip")
    refute matcher("/status/glitchtip").match?("/status/glitchtip")
  end

  test "no patterns match nothing" do
    refute matcher.match?("/issues")
    refute matcher("", "  ").match?("/issues")
  end

  test "patterns are listed from a text, one per line, blank lines ignored" do
    assert_equal ["/issues", "/projects/*/issues"], RubylodeGlitchtip::PathMatcher.patterns_from("/issues\n\n  /projects/*/issues  \r\n")
    assert_equal [], RubylodeGlitchtip::PathMatcher.patterns_from(nil)
  end
end
