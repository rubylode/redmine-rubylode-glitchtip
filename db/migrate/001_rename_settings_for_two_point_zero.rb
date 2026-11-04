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

require_relative "../../lib/rubylode_glitchtip/settings"
require_relative "../../lib/rubylode_glitchtip/settings_migration"

# Version 2.0.0 renamed some settings and changed what "My page" means. See RubylodeGlitchtip::SettingsMigration.
class RenameSettingsForTwoPointZero < ActiveRecord::Migration[6.1]
  def up
    RubylodeGlitchtip::SettingsMigration.up
  end

  def down
    RubylodeGlitchtip::SettingsMigration.down
  end
end
