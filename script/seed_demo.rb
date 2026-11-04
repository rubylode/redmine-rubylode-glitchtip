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

# Demo data for trying the plugin: two people, a project with a wiki page that uses the macro, and the plugin pointed at
# the fake GlitchTip of docker-compose.yml. Everything is made up. Only for the throwaway Redmine in docker-compose.yml.
#
#   ruby bin/demo up        (runs this script)
#   docker compose exec redmine bin/rails runner plugins/redmine_rubylode_glitchtip/script/seed_demo.rb
#
# Safe to run twice. The administrator is admin / admin, the other person sam.rivera / demo-password-1.

DEMO_PASSWORD = "demo-password-1".freeze
PLUGIN_ID = :redmine_rubylode_glitchtip

def ensure_default_data
  return if Tracker.exists? && IssueStatus.exists? && IssuePriority.exists?

  Redmine::DefaultData::Loader.load("en")
end

# Preview only: the throwaway Redmine asks for a new administrator password on first sign-in. The short password skips
# Redmine's length rule on purpose; never run this against a real tracker.
def ensure_preview_admin
  admin = User.find_by!(login: "admin")
  admin.password = admin.password_confirmation = "admin"
  admin.must_change_passwd = false
  admin.save!(validate: false)
  admin
end

def ensure_user(login, firstname, lastname)
  user = User.find_or_initialize_by(login: login)
  if user.new_record?
    user.assign_attributes(firstname: firstname, lastname: lastname, mail: "#{login}@example.com", language: "en",
                           password: DEMO_PASSWORD, password_confirmation: DEMO_PASSWORD, must_change_passwd: false)
    user.save!
  end
  user
end

def ensure_project(member)
  project = Project.find_or_initialize_by(identifier: "storefront")
  project.name = "Storefront"
  project.is_public = true
  project.enabled_module_names = (Setting.default_projects_modules + %w[issue_tracking wiki]).uniq
  project.trackers = Tracker.all
  project.save!
  role = Role.find_or_create_by!(name: "Demo member") { |created| created.permissions = %i[view_issues view_wiki_pages] }
  Member.create!(project: project, user: member, roles: [role]) unless project.members.exists?(user_id: member.id)
  project
end

def ensure_wiki_page(project, author)
  project.wiki || Wiki.create!(project: project, start_page: "Wiki")
  page = project.wiki.find_or_new_page("Wiki")
  return if page.content

  page.content = WikiContent.new(author: author, text: <<~TEXT)
    h1. Storefront

    Errors that may need attention right now:

    {{glitchtip_status}}
  TEXT
  page.save!
end

User.current = User.find_by!(login: "admin")
Mailer.with_deliveries(false) do
  ensure_default_data
  Setting.default_language = "en"
  Setting.notified_events = []
  admin = ensure_preview_admin
  sam = ensure_user("sam.rivera", "Sam", "Rivera")
  project = ensure_project(sam)
  ensure_wiki_page(project, admin)

  # The fake GlitchTip is on the compose network under plain http, hence the "allow plain http" box. The cache is off
  # so that "ruby bin/demo scenario NAME" shows at once.
  Setting.send(:"plugin_#{PLUGIN_ID}=", Setting.send(:"plugin_#{PLUGIN_ID}").to_h.merge(
    "base_url" => "http://fake_glitchtip:9100", "organization_slug" => "demo-org", "allow_plain_http" => "1",
    "cache_seconds" => "0", "failure_cache_seconds" => "0", "levels" => %w[fatal error warning],
    "show_on_welcome_page" => "1", "welcome_page_column" => "right", "show_on_matching_pages" => "1", "matching_page_paths" => "/issues\n/projects/*/issues",
    "show_in_top_menu" => "1"
  ))

  [admin, sam].each do |user|
    preference = user.pref
    preference.my_page_layout = { "top" => ["rubylode_glitchtip_status"], "left" => ["issuesassignedtome"], "right" => [] }
    preference.save!
  end
end

puts "Plugin settings: #{Setting.send(:"plugin_#{PLUGIN_ID}").inspect}"
puts "People: admin / admin, sam.rivera / #{DEMO_PASSWORD}"
