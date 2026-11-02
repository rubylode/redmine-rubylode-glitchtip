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

class RubylodeGlitchtip::WikiMacroTest < Redmine::IntegrationTest
  include RubylodeGlitchtipTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  setup do
    use_memory_cache
    configure_plugin
    now = Time.now.utc
    publish_issues([issue_hash(id: "7", title: "Boom", first_seen: (now - 3600).iso8601, last_seen: (now - 300).iso8601)])
  end

  teardown do
    restore_cache
  end

  def get_wiki_page(text, login: "jsmith")
    page = WikiPage.new(wiki: Project.find(1).wiki, title: "Errors_#{SecureRandom.hex(3)}")
    page.content = WikiContent.new(text: text, author: User.find(2))
    page.save!
    log_user(login, login)
    get "/projects/ecookbook/wiki/#{page.title}"
    assert_response :success
  end

  test "the macro draws the errors block inside the wiki page" do
    get_wiki_page("Right now:\n\n{{glitchtip_errors}}")

    assert_select ".wiki .rubylode-glitchtip-errors-summary", text: "1 issue needs attention, 5 events"
    assert_select ".wiki tr.is-error td.rubylode-glitchtip-errors-title-cell", text: /Boom/
  end

  test "the macro takes a title" do
    get_wiki_page("{{glitchtip_errors(title=Production errors)}}")

    assert_select ".wiki h3.rubylode-glitchtip-errors-title", text: /\AProduction errors/
  end

  test "the macro uses the block title setting when it has no title" do
    configure_plugin("block_title" => "Our errors")
    get_wiki_page("{{glitchtip_errors}}")

    assert_select ".wiki h3.rubylode-glitchtip-errors-title", text: /\AOur errors/
  end

  test "a title with markup in the macro is escaped" do
    get_wiki_page("{{glitchtip_errors(title=<b>x</b>)}}")

    assert_select ".wiki h3.rubylode-glitchtip-errors-title b", 0
  end

  test "the macro draws nothing for a person the settings do not allow" do
    configure_plugin("visibility" => "admins")
    get_wiki_page("before {{glitchtip_errors}} after")

    assert_select ".rubylode-glitchtip-errors", 0
  end

  test "the macro is listed in the macro help" do
    assert Redmine::WikiFormatting::Macros.available_macros.key?(:glitchtip_errors)
  end
end
