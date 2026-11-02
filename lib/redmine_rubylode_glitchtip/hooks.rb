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

module RedmineRubylodeGlitchtip
  # Puts the errors block where the settings ask for it: Redmine's welcome (Home) page, a project's Overview page, and
  # the end of any page whose path matches the path patterns. The block is the same partial as everywhere else, so
  # permission, caching and the "status unavailable" fallback are the same too.
  class Hooks < Redmine::Hook::ViewListener
    def view_welcome_index_left(context)
      render_on_welcome_page(context, "left")
    end

    def view_welcome_index_right(context)
      render_on_welcome_page(context, "right")
    end

    def view_projects_show_left(context)
      render_on_project_overview(context, "left")
    end

    def view_projects_show_right(context)
      render_on_project_overview(context, "right")
    end

    # Runs on every page, after its content. Only a plain page view of a path in the list gets the block (not an AJAX
    # request, not a form post), drawn in its compact variant. The page is already past its head, so the partial brings its
    # own stylesheet link.
    def view_layouts_base_content(context)
      request = context[:request]
      return "" unless request&.get? && !request.xhr?

      configuration = RubylodeGlitchtip::Configuration.current
      return "" unless RubylodeGlitchtip::PathMatcher.new(configuration.path_patterns).match?(request.path)

      context[:hook_caller].render(partial: "rubylode_glitchtip/errors", locals: { compact: true, inline_stylesheet: true })
    end

    private

    def render_on_welcome_page(context, column)
      configuration = RubylodeGlitchtip::Configuration.current
      return "" unless configuration.show_on_welcome_page? && configuration.welcome_page_column == column

      context[:hook_caller].render(partial: "rubylode_glitchtip/errors")
    end

    def render_on_project_overview(context, column)
      configuration = RubylodeGlitchtip::Configuration.current
      return "" unless configuration.show_on_project_overview? && configuration.project_overview_column == column

      context[:hook_caller].render(partial: "rubylode_glitchtip/errors")
    end
  end
end
