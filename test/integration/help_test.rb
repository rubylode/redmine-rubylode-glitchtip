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
    assert_select ".rubylode-glitchtip-help pre", text: /\{\{glitchtip_status\}\}/
    assert_select ".rubylode-glitchtip-help pre", text: /\{\{glitchtip_status\(title=Production errors\)\}\}/
    assert_select ".rubylode-glitchtip-help pre", text: %r{/projects/\*/issues}
    assert_select ".rubylode-glitchtip-help pre", text: /render partial: "rubylode_glitchtip\/status"/
    assert_select ".rubylode-glitchtip-help pre", text: /compact: true/
    assert_select ".rubylode-glitchtip-help-table th", text: "Needs a setting"
    assert_select ".rubylode-glitchtip-help-table tbody tr", 9
  end

  test "the help says the welcome text takes the macro" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    assert_select ".rubylode-glitchtip-help p", text: /welcome text \(Administration, Settings, General\)/
  end

  test "the help names the page and says how the top menu entry works" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    assert_select ".rubylode-glitchtip-help p", text: %r{/status/glitchtip.*Show in the top menu}m
  end

  test "the settings form has every placement field" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    %w[show_on_my_page show_on_welcome_page welcome_page_column show_on_project_overview project_overview_column
       show_on_matching_pages matching_page_paths show_in_top_menu].each do |field|
      assert_select "[name=?]", "settings[#{field}]"
    end
  end

  test "each column select has a visible label" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_glitchtip"

    %w[welcome_page_column project_overview_column].each do |field|
      assert_select "label[for=settings_#{field}]", text: "Column"
    end
  end

  test "the top menu setting is hidden while the Status plugin is installed, and its value is kept" do
    log_user("admin", "admin")
    configure_plugin("show_in_top_menu" => "1")
    with_status_plugin_installed(true) do
      get "/settings/plugin/redmine_rubylode_glitchtip"
    end

    assert_select "input[type=checkbox][name=?]", "settings[show_in_top_menu]", 0
    assert_select "input[type=hidden][name=?][value=?]", "settings[show_in_top_menu]", "1"
    assert_select ".rubylode-status-notice a[href=?]", "/status", text: "Status page"
  end

  test "the top menu setting shows while the Status plugin is missing, with the notice that points to it" do
    log_user("admin", "admin")
    with_status_plugin_installed(false) do
      get "/settings/plugin/redmine_rubylode_glitchtip"
    end

    assert_select "input[type=checkbox][name=?]", "settings[show_in_top_menu]"
    assert_select ".rubylode-status-notice", text: "Install Rubylode Status to see this with the other status blocks on one page."
    assert_select ".rubylode-status-notice a[href=?]", "https://github.com/rubylode/redmine-rubylode-status"
  end

  test "the readme has the standard headings in order and four install steps" do
    headings = README.scan(/^## (.+)$/).flatten
    standard = %w[Install Settings] + ["Where it shows", "Security", "Troubleshooting", "Tests", "License"]

    assert_equal standard, headings & standard
    install = README[/^## Install\n(.*?)^## /m, 1]
    assert_equal 4, install.scan(/^\d\. /).size
  end

  test "nothing a person reads says the old title or the old setting names" do
    texts = [README, File.read(File.expand_path("../../config/locales/en.yml", __dir__)), File.read(File.expand_path("../../docs/redmine-org-listing.md", __dir__))]
    texts.each do |text|
      refute_includes text, "Errors needing attention"
      refute_includes text, "Who may see it"
      refute_match(/[–—]/, text)
    end
  end

  test "the readme carries the same section, snippets and table" do
    assert_includes README, "## Where it shows"
    assert_includes README, "{{glitchtip_status}}"
    assert_includes README, 'render partial: "rubylode_glitchtip/status"'
    assert_includes README, "/projects/*/issues"
    assert_includes README, "| Place | How | Needs a setting |"
  end
end
