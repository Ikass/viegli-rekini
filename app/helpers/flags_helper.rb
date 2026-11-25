# frozen_string_literal: true

# Inline SVG flags for the language switcher. Flags are SVGs rather than
# emoji so they render identically on every platform (flag emoji degrade to
# "GB"/"LV" letter pairs on Windows).
module FlagsHelper
  def flag_svg(code, **options)
    file = Rails.root.join("app/assets/images/flags/#{code}.svg")
    return unless file.exist?

    classes = [ "flag", options.delete(:class) ].compact.join(" ")
    svg = File.read(file)
    svg.sub("<svg", %(<svg class="#{classes}")).html_safe
  end
end
