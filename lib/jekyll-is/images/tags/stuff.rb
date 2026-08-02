# frozen_string_literal: true

require_relative '../stuff'

module JekyllIS::Images::Tags; end

class JekyllIS::Images::Tags::Stuff < Liquid::Tag

  def initialize tag, text, tokens
    super(tag, text, tokens)
    @tag = tag
  end

  # @return [String]
  def render context
    ctx = JekyllIS::Images::Context[context.registers[:site], context.registers[:page].instance_variable_get('@obj')]
    case @tag
    when 'is_images_stuff'
      "#{ css_loader(ctx) }\n#{ js_loader(ctx) }"
    when 'is_images_css'
      css_loader(ctx)
    when 'is_images_js'
      js_loader(ctx)
    else
      ''
    end
  end

  private

  def css_loader context
    "<link rel=\"stylesheet\" href=\"#{ JekyllIS::Images::Assets::CSS::loader(context).url }\" />"
  end

  def js_loader context
    "<script type=\"module\" src=\"#{ JekyllIS::Images::Assets::JS::loader(context).url }\"></script>"
  end

end

Liquid::Template::register_tag 'is_images_stuff', JekyllIS::Images::Tags::Stuff
Liquid::Template::register_tag 'is_images_css',   JekyllIS::Images::Tags::Stuff
Liquid::Template::register_tag 'is_images_js',    JekyllIS::Images::Tags::Stuff
