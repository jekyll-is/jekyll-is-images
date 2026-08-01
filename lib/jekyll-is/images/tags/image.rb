# frozen_string_literal: true

require_relative '../context'
require_relative '../kramdown/image'
require_relative '../kramdown/figure'

module JekyllIS::Images::Tags; end

class JekyllIS::Images::Tags::Image < Liquid::Tag

  def initialize tag, markup, tokens
    super(tag, markup, tokens)
    @markup = markup
  end

  # @return [String]
  def render context
    site = context.registers[:site]
    page = context.registers[:page].instance_variable_get('@obj')
    cont = JekyllIS::Images::Context[site, page]
    markdown = "![](){: #{ @markup } }"
    document = Kramdown::Document::new(markdown)
    element = document.root&.children&.first
    element = element.children&.first if element&.type == :p
    raise "Invalid markup: #{ @markup.inspect }" unless element
    flags = element.options&.dig(:ial, :refs) || []
    if flags.delete('figure')
      raise "Invalid context — figure inside gallery: #{ @markup.inspect }" if context.registers[:is_images_gallery]
      para = Kramdown::Element::new :p
      para.children = [ element ]
      figure = JekyllIS::Images::Kramdown::Figure::new cont
      figure.apply para
      if context.registers[:is_images_to_latex]
        figure.to_latex
      else
        figure.to_html
      end
    elsif context.registers[:is_images_gallery]
      context.registers[:is_images_gallery] << element
      ''
    else
      image = JekyllIS::Images::Kramdown::Image::new cont
      image.apply element
      if context.registers[:is_images_to_latex]
        image.to_latex
      else
        image.to_html
      end
    end
  end

end

Liquid::Template::register_tag 'image', JekyllIS::Images::Tags::Image
