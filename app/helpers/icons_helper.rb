module IconsHelper
  def tabler_icon(name, **options)
    file = Rails.root.join("app/assets/images/icons/tabler/#{name}.svg")
    return unless file.exist?

    classes = [ "icon", options.delete(:class) ].compact.join(" ")
    tag.span(File.read(file).html_safe, **options, class: classes, aria: { hidden: true })
  end
end
