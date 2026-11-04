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
require_relative "lib/rubylode_glitchtip/settings"

Redmine::Plugin.register :redmine_rubylode_glitchtip do
  name "Rubylode GlitchTip"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  url "https://github.com/rubylode/redmine-rubylode-glitchtip"
  description "Recent GlitchTip errors that may need attention: a wiki macro, a page, a My page block, a partial and a Status page widget"
  version "2.0.0"
  requires_redmine version_or_higher: "5.1.0"

  # An optional link in the top menu to the page. A menu item has no setting of its own in Redmine, so the item is always
  # registered and shows only while "Show in the top menu" is checked and the person may see the block. With Rubylode
  # Status installed the block is on its page, so the item goes.
  menu :top_menu, :rubylode_glitchtip_status, { controller: "rubylode_glitchtip_status", action: "show" },
       caption: ->(_project) { RubylodeGlitchtip::Settings.current.block_title },
       if: lambda { |_project|
         settings = RubylodeGlitchtip::Settings.current
         !RubylodeGlitchtip::Settings.status_plugin_installed? && settings.show_in_top_menu? && settings.visible_to?(User.current)
       }

  settings default: RubylodeGlitchtip::Settings::DEFAULTS, partial: "settings/rubylode_glitchtip"
end

require_relative "lib/rubylode_glitchtip/hooks"
require_relative "lib/rubylode_glitchtip/macros"
RubylodeGlitchtip::Macros.register_all
require_relative "lib/rubylode_glitchtip/my_page_patch"
require_relative "lib/rubylode_glitchtip/settings_controller_patch"

# Redmine runs this file again on every code reload, so the patches go in only once.
apply_patches = lambda do
  unless SettingsController.include?(RubylodeGlitchtip::SettingsControllerPatch)
    SettingsController.prepend RubylodeGlitchtip::SettingsControllerPatch
  end
  unless Redmine::MyPage.singleton_class.include?(RubylodeGlitchtip::MyPagePatch)
    Redmine::MyPage.singleton_class.prepend RubylodeGlitchtip::MyPagePatch
  end
end
apply_patches.call
Rails.configuration.to_prepare(&apply_patches)

# Puts the block on the Status page when Rubylode Status is installed. See its docs/widget-contract.md.
Rails.application.config.after_initialize do
  if defined?(RubylodeStatus::Registry)
    RubylodeGlitchtip::StatusWidget.register(RubylodeStatus::Registry)
  end
end
