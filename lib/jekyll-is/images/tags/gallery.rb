# frozen_string_literal: true

require_relative '../kramdown/figure'

module JekyllIS::Images::Tags; end

class JekyllIS::Images::Tags::Gallery < Liquid::Block

  def initialize tag, markup, tokens
    super(tag, markup, tokens)
    @markup = markup
  end

  # @return [String]
  def render context
    raise "Invalid context — nested gallery: #{ markup.inspect }" if context.registers[:is_images_gallery]
    context.registers[:is_images_gallery] = []
    markdown = "{: #{ @markup } }\n "
    document = Kramdown::Document::new(markdown)
    element = document.root&.children&.first
    raise "Invalid markup: #{ @markup.inspect }" unless element
    super(context)
    raise "Empty gallery: #{ @markup.inspect }" if context.registers[:is_images_gallery].size < 0
    element.children = context.registers[:is_images_gallery]
    context.registers.delete :is_images_gallery
    site = context.registers[:site]
    page = context.registers[:page]
    cont = JekyllIS::Images::Context[site, page]
    gallery = JekyllIS::Images::Kramdown::Figure::new cont
    gallery.apply element
    if context.registers[:is_images_to_latex]
      figure.to_latex
    else
      figure.to_html
    end
  end

end

Liquid::Template::register_tag 'gallery', JekyllIS::Images::Tags::Gallery
