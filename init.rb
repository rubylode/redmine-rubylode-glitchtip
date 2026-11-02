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

require "redmine"
require_relative "lib/redmine_rubylode_glitchtip/defaults"

Redmine::Plugin.register :redmine_rubylode_glitchtip do
  name "Rubylode GlitchTip"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  description "Recent GlitchTip errors that may need attention: a wiki macro, a page, a My page block and a partial"
  version "0.2.1"
  requires_redmine version_or_higher: "7.0.0"

  # An optional link in the top menu to the page. A menu item has no setting of its own in Redmine, so the item is always
  # registered and shows only while "Show in the top menu" is ticked and the person may see the block.
  menu :top_menu, :rubylode_glitchtip_errors, { controller: "rubylode_glitchtip_errors", action: "show" },
       caption: ->(_project) { RubylodeGlitchtip::Configuration.current.block_title },
       if: lambda { |_project|
         configuration = RubylodeGlitchtip::Configuration.current
         configuration.show_in_top_menu? && configuration.visible_to?(User.current)
       }

  settings default: RedmineRubylodeGlitchtip::Defaults::SETTINGS, partial: "settings/rubylode_glitchtip"
end

require_relative "lib/redmine_rubylode_glitchtip/hooks"
require_relative "lib/redmine_rubylode_glitchtip/macros"
RedmineRubylodeGlitchtip::Macros.register_all
require_relative "lib/redmine_rubylode_glitchtip/settings_controller_patch"

# Redmine runs this file again on every code reload, so the patch goes in only once.
apply_settings_controller_patch = lambda do
  unless SettingsController.include?(RedmineRubylodeGlitchtip::SettingsControllerPatch)
    SettingsController.prepend RedmineRubylodeGlitchtip::SettingsControllerPatch
  end
end
apply_settings_controller_patch.call
Rails.configuration.to_prepare(&apply_settings_controller_patch)
