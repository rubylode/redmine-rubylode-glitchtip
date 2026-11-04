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
  # "My page" in the settings adds the block to the default My page, the one people get until they arrange their own.
  # A layout a person already saved is never touched, and the block stays in everyone's block list either way.
  module MyPagePatch
    def default_layout
      layout = super
      return layout unless RubylodeGlitchtip::Settings.current.show_on_my_page?

      layout.merge("top" => Array(layout["top"]) + [BLOCK])
    end

    BLOCK = "rubylode_glitchtip_status".freeze
  end
end
