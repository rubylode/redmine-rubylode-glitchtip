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
require_relative "../../db/migrate/001_rename_settings_for_two_point_zero"

class RubylodeGlitchtip::SettingsMigrationTest < ActiveSupport::TestCase
  include RubylodeGlitchtipTestHelpers

  SETTING_NAME = RubylodeGlitchtip::SettingsMigration::SETTING_NAME

  # Redmine 1.x settings, as the form saved them.
  VERSION_ONE = {
    "base_url" => "https://glitchtip.example.com", "organization_slug" => "example-org", "lookback_hours" => "12",
    "block_title" => "Errors needing attention", "show_on_my_page" => "1", "path_patterns" => "/issues\n/projects/*/issues",
    "show_in_top_menu" => "1", "maximum_rows" => "7"
  }.freeze

  setup do
    Setting.where(name: SETTING_NAME).delete_all
    Setting.clear_cache
  end

  def save(hash)
    Setting.send(:"plugin_#{PLUGIN_ID}=", hash)
  end

  def saved
    Setting.clear_cache
    Setting.where(name: SETTING_NAME).first.value.to_h.stringify_keys
  end

  def migrate(direction)
    RenameSettingsForTwoPointZero.new.migrate(direction)
  end

  test "up moves the renamed keys and keeps every other value" do
    save(VERSION_ONE.dup)
    silence_migration { migrate(:up) }
    result = saved

    assert_equal "12", result["look_back_hours"]
    assert_equal "/issues\n/projects/**/issues", result["matching_page_paths"]
    assert_equal "1", result["show_on_matching_pages"]
    refute result.key?("lookback_hours")
    refute result.key?("path_patterns")
    assert_equal "https://glitchtip.example.com", result["base_url"]
    assert_equal "7", result["maximum_rows"]
    assert_equal "1", result["show_in_top_menu"]
  end

  test "up turns the old My page gate, on or off, into the new setting off, so nothing people see changes" do
    ["1", "0"].each do |old_value|
      save(VERSION_ONE.merge("show_on_my_page" => old_value))
      silence_migration { migrate(:up) }

      assert_equal "0", saved["show_on_my_page"], "old value #{old_value}"
    end
  end

  test "up leaves the matching pages off when there were no paths" do
    save(VERSION_ONE.merge("path_patterns" => " \n"))
    silence_migration { migrate(:up) }

    assert_equal "0", saved["show_on_matching_pages"]
  end

  test "up moves the old default title to Errors and keeps a title the owner chose" do
    save(VERSION_ONE.dup)
    silence_migration { migrate(:up) }
    assert_equal "Errors", saved["block_title"]

    save(VERSION_ONE.merge("block_title" => "Production errors"))
    silence_migration { migrate(:up) }
    assert_equal "Production errors", saved["block_title"]
  end

  test "nothing is written when nothing was saved, in either direction" do
    silence_migration { migrate(:up) }
    assert_equal 0, Setting.where(name: SETTING_NAME).count

    silence_migration { migrate(:down) }
    assert_equal 0, Setting.where(name: SETTING_NAME).count
  end

  test "running up twice changes nothing the second time" do
    save(VERSION_ONE.dup)
    silence_migration { migrate(:up) }
    first = saved
    save(first.merge("show_on_my_page" => "1"))
    silence_migration { migrate(:up) }

    assert_equal "1", saved["show_on_my_page"], "settings already in the 2.0.0 shape are left alone"
  end

  test "up turns every star into two stars, so saved patterns keep their meaning" do
    save(VERSION_ONE.merge("path_patterns" => "/a/*\n/b*c\n/d/**"))
    silence_migration { migrate(:up) }

    assert_equal "/a/**\n/b**c\n/d/**", saved["matching_page_paths"]
  end

  test "down turns two stars back into one" do
    save(RubylodeGlitchtip::Settings::DEFAULTS.merge("matching_page_paths" => "/a/**\n/b**c", "show_on_matching_pages" => "1"))
    silence_migration { migrate(:down) }

    assert_equal "/a/*\n/b*c", saved["path_patterns"]
  end

  test "down moves the keys back and puts the old gate on" do
    save(VERSION_ONE.dup)
    silence_migration { migrate(:up) }
    silence_migration { migrate(:down) }
    result = saved

    assert_equal "12", result["lookback_hours"]
    assert_equal "/issues\n/projects/*/issues", result["path_patterns"]
    assert_equal "1", result["show_on_my_page"]
    assert_equal "Errors needing attention", result["block_title"]
    %w[look_back_hours matching_page_paths show_on_matching_pages].each { |key| refute result.key?(key), key }
    assert_equal "7", result["maximum_rows"]
  end

  test "down drops the paths that were switched off, because 1.x would draw the block on them" do
    save(RubylodeGlitchtip::Settings::DEFAULTS.merge("matching_page_paths" => "/issues", "show_on_matching_pages" => "0"))
    silence_migration { migrate(:down) }

    assert_equal "", saved["path_patterns"]
  end

  test "down keeps a title the owner chose" do
    save(RubylodeGlitchtip::Settings::DEFAULTS.merge("block_title" => "Production errors"))
    silence_migration { migrate(:down) }

    assert_equal "Production errors", saved["block_title"]
  end

  private

  def silence_migration(&block)
    ActiveRecord::Migration.suppress_messages(&block)
  end
end
