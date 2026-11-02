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

class RubylodeGlitchtip::HelpTest < Redmine::IntegrationTest
  include RubylodeGlitchtipTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles

  README = File.read(File.expand_path("../../README.md", __dir__))

  test "the settings page explains how to show the block on other pages, with snippets and the table" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    assert_select ".rubylode-glitchtip-help h3", text: "How to show the block on other pages"
    assert_select ".rubylode-glitchtip-help pre", text: /\{\{glitchtip_errors\}\}/
    assert_select ".rubylode-glitchtip-help pre", text: /\{\{glitchtip_errors\(title=Production errors\)\}\}/
    assert_select ".rubylode-glitchtip-help pre", text: %r{/projects/\*/issues}
    assert_select ".rubylode-glitchtip-help pre", text: /render partial: "rubylode_glitchtip\/errors"/
    assert_select ".rubylode-glitchtip-help pre", text: /compact: true/
    assert_select ".rubylode-glitchtip-help-table th", text: "Needs a setting"
    assert_select ".rubylode-glitchtip-help-table tbody tr", 9
  end

  test "the help says the welcome text runs macros, because Redmine draws it with its text formatter" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    assert_select ".rubylode-glitchtip-help p", text: /welcome text.*textilizable/m
  end

  test "the help names the page and says how the top menu entry works" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    assert_select ".rubylode-glitchtip-help p", text: %r{/glitchtip_errors.*Show in the top menu}m
  end

  test "the settings form has every placement field" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    %w[show_on_my_page show_on_welcome_page welcome_page_column show_on_project_overview project_overview_column path_patterns
       show_in_top_menu].each do |field|
      assert_select "[name=?]", "settings[#{field}]"
    end
  end

  test "the readme carries the same section, snippets and table" do
    assert_includes README, "## How to show the block on other pages"
    assert_includes README, "{{glitchtip_errors}}"
    assert_includes README, 'render partial: "rubylode_glitchtip/errors"'
    assert_includes README, "/projects/*/issues"
    assert_includes README, "| Place | How | Needs a setting |"
    assert_includes README, "textilizable"
  end
end
