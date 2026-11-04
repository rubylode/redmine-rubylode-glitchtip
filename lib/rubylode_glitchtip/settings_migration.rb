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

module RubylodeGlitchtip
  # Moves the saved plugin settings between the 1.x names and the 2.0.0 names. Run by db/migrate/001_rename_settings_for_two_point_zero.rb.
  # Nothing is written when no settings were ever saved, because then the defaults apply and there is nothing to move.
  #
  #   1.x                         2.0.0
  #   lookback_hours              look_back_hours
  #   path_patterns               matching_page_paths, every * becoming **, and show_on_matching_pages is on when there were any
  #   show_on_my_page (a gate)    show_on_my_page (adds the block to the default My page), always off, so nobody sees a change
  #   block_title "Errors needing attention"   "Errors"; a title the owner chose stays
  class SettingsMigration
    SETTING_NAME = "plugin_#{PLUGIN_ID}".freeze
    PREVIOUS_BLOCK_TITLE = "Errors needing attention".freeze
    NEW_BLOCK_TITLE = "Errors".freeze

    def self.up
      new.up
    end

    def self.down
      new.down
    end

    def up
      change do |saved|
        next false if saved.key?("look_back_hours") || saved.key?("matching_page_paths")

        saved["look_back_hours"] = saved.delete("lookback_hours") if saved.key?("lookback_hours")
        if saved.key?("path_patterns")
          # A 1.x star matched anything; in 2.0.0 that is two stars, so every saved pattern keeps its meaning.
          paths = saved.delete("path_patterns").to_s.gsub(/\*+/, "**")
          saved["matching_page_paths"] = paths
          saved["show_on_matching_pages"] = paths.strip.empty? ? "0" : "1"
        end
        saved["show_on_my_page"] = "0"
        saved["block_title"] = NEW_BLOCK_TITLE if saved["block_title"] == PREVIOUS_BLOCK_TITLE
        true
      end
    end

    # The reverse. Paths come back only while "Pages matching these paths" is on, because 1.x had no such switch and
    # would draw the block on them. My page goes back to the gate, on.
    def down
      change do |saved|
        next false unless saved.key?("look_back_hours") || saved.key?("matching_page_paths")

        saved["lookback_hours"] = saved.delete("look_back_hours") if saved.key?("look_back_hours")
        if saved.key?("matching_page_paths")
          paths = saved.delete("matching_page_paths").to_s.gsub(/\*+/, "*")
          saved["path_patterns"] = saved["show_on_matching_pages"].to_s == "1" ? paths : ""
        end
        saved.delete("show_on_matching_pages")
        saved["show_on_my_page"] = "1"
        saved["block_title"] = PREVIOUS_BLOCK_TITLE if saved["block_title"] == NEW_BLOCK_TITLE
        true
      end
    end

    private

    # Yields the saved settings as a plain hash. Saves them when the block returns true.
    def change
      row = Setting.where(name: SETTING_NAME).first
      return false if row.nil?

      saved = row.value.to_h.stringify_keys
      return false unless yield(saved)

      row.value = saved
      row.save!
      Setting.clear_cache
      true
    end
  end
end
