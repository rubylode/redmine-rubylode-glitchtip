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
  # The wiki macro. Redmine's autoloader expects a constant named after the file, hence the module.
  module Macros
    def self.register_all
      Redmine::WikiFormatting::Macros.register do
        desc <<~DESCRIPTION
          Shows the recent GlitchTip errors that need attention, as set in the Rubylode GlitchTip settings.
            {{glitchtip_status}}
            {{glitchtip_status(title=Production errors)}}
          Nothing is shown to people who are not allowed to see it.
        DESCRIPTION
        macro :glitchtip_status do |_object, arguments|
          _positional, options = extract_macro_options(arguments, :title)
          render partial: "rubylode_glitchtip/status", locals: { title: options[:title].presence }
        end

        desc <<~DESCRIPTION
          The name before 2.0.0 of {{glitchtip_status}}, kept for one release. It shows the same thing.
            {{glitchtip_errors}}
        DESCRIPTION
        macro :glitchtip_errors do |_object, arguments|
          _positional, options = extract_macro_options(arguments, :title)
          render partial: "rubylode_glitchtip/status", locals: { title: options[:title].presence }
        end
      end
    end
  end
end
