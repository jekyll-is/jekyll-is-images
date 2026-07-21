# frozen_string_literal: true

require_relative 'value'

class JekyllIS::Images::Kramdown::Figure < JekyllIS::Images::Kramdown::Value

  def type = :is_figure
  def category = :block

  attr_reader :children

  def initialize context
    super(context)
    @children = []
  end

  def gallery?
    @children.size > 1
  end

  attr_reader :caption, :modes

  def apply element
    super(element)
    @caption = @attrs.delete('caption')
    @caption_position = @attrs.delete('caption-position')
    @modes = @attrs.delete('modes')&.split(',') || @context.config('gallery', 'modes')&.split(',') || []
    element.children.each do |child|
      if [ :a, :img ].include?(child.type)
        image = JekyllIS::Images::Kramdown::Image::new @context, figure: self
        image.apply child
        @children << image
      end
    end

    if @children.size == 1
      image = @children.first
      @caption ||= image.caption
      @caption_position ||= image.caption_position
      @attrs = image.attrs.merge(@attrs)
      # «Крадём» классы и флаги.
      @flags.merge image.flags
      image.flags.clear
      @classes.merge image.classes
      image.classes.clear
    end

    if gallery?
      @caption_position ||= @context.config('gallery', 'caption_position')
    else
      @caption_position ||= @context.config('caption_position')
    end

    if @children.size == 0
      @context.error "Invalid figure (without images) on page #{ @context.page.relative_path.inspect }"
    end
    if @children.site > 1 && @modes.empty?
      @context.error "Invalid gallery (without modes) on page #{ @context.page.relative_path.inspect }"
    end
  end

  def to_html
    case @children.size
    when 0
      @context.error "Invalid figure (without images) on page #{ @context.page.relative_path.inspect }"
    when 1
      generate_simple_html
    else
      if @modes.empty?
        @context.error "Invalid gallery (without modes) on page #{ @context.page.relative_path.inspect }"
      else
        @context.page.data['__is_images_has_galleries'] = true
        gallery = @modes.map { send "generate_#{ it }_html" }.join("\n")
        generate_outer_html gallery
      end
    end
  end

  private

  def generate_outer_html inner

    classes = @classes.dup
    classes << '__is_images_figure'
    classes << '__is_images_gallery' if gallery?
    @flags.each do |flag|
      classes << "__is_images__#{ flag }"
    end

    styles = @styles.dup

    fig_attrs = {}
    fig_attrs['id'] = @id if @id
    fig_attrs['class'] = classes.join(' ') unless classes.empty?
    fig_attrs['style'] = styles.map { |k, v| "#{ k }:#{ v };" }.join('') unless styles.empty?
    fig_attrs['data-modes'] = @modes.join(',') unless @modes.empty?

    if @caption_position == 'top'
      inner = "<figcaption>#{ process_caption(@caption) }</figcaption>\n#{ inner }"
    else
      inner = "#{ inner }\n<figcaption>#{ process_caption(@caption) }</figcaption>"
    end

    "<figure #{ fig_attrs.map { |k, v| "#{ k }=\"#{ v }\"" }.join(' ') }>\n#{ inner }\n</figure>"
  end

  def generate_simple_html
    overlay = { 'mode' => 'single' }   # Мы НЕ перекрываем ничего для одиночного изображения.
    generate_outer_html @children.first.to_html(overlay: overlay)
  end

  def generate_grid_html
    attrs = @attrs.dup
    overlay = {}
    overlay['format'] = attrs.delete('cell-format') || @context.config('grid', 'format')
    overlay['width']  = attrs.delete('cell-width')  || @context.config('grid', 'width')
    overlay['height'] = attrs.delete('cell-height') || @context.config('grid', 'height')
    overlay['scale']  = attrs.delete('cell-scale')  || @context.config('grid', 'scale')
    overlay['crop']   = attrs.delete('cell-crop')   || @context.config('grid', 'crop')
    overlay['fit']    = attrs.delete('cell-fit')    || @context.config('grid', 'fit')
    overlay['salt']   = attrs.delete('salt')
    overlay['attrs']  = attrs
    overlay['mode']   = 'cell'
    items = @children.map do |image|
      inner = image.to_html(overlay: overlay)
      caption = image.caption ? "<figcaption>#{ process_caption(image.caption) }</figcaption>" : ''
      if (@attrs['cell-caption-position'] || @context.config('cell_caption_position')) == 'top'
        inner = "#{ caption }\n#{ inner }"
      else
        inner = "#{ inner }\n#{ caption }"
      end
      "<figure class=\"__is_images_cell_figure\">\n#{ inner }\n</figure>"
    end
    "<div class=\"__is_images_grid_container\">#{ items.join("\n") }</div>"
  end

  def generate_slides_html
    attrs = @attrs.dup
    overlay = {}
    overlay['format'] = attrs.delete('slide-format') || @context.config('slides', 'format')
    overlay['width']  = attrs.delete('slide-width')  || @context.config('slides', 'width')
    overlay['height'] = attrs.delete('slide-height') || @context.config('slides', 'height')
    overlay['scale']  = attrs.delete('slide-scale')  || @context.config('slides', 'scale')
    overlay['crop']   = attrs.delete('slide-crop')   || @context.config('slides', 'crop')
    overlay['fit']    = attrs.delete('slide-fit')    || @context.config('slides', 'fit')
    overlay['salt']   = attrs.delete('salt')
    overlay['attrs']  = attrs
    overlay['mode']   = 'slide'
    items = @children.map do |image|
      inner = image.to_html(overlay: overlay)
      caption = image.caption ? "<figcaption>#{ process_caption(image.caption) }</figcaption>" : ""
      if (@attrs['slide-caption-position'] || @context.config('slide_caption_position')) == 'top'
        inner = "#{caption}\n#{inner}"
      else
        inner = "#{inner}\n#{caption}"
      end
      "<figure class=\"__is_images_slide_figure\">\n#{inner}\n</figure>"
    end
    "<div class=\"__is_images_slides_container\">#{items.join("\n")}</div>"
  end

  def process_caption caption
    @context.site.find_converter_instance(Jekyll::Converters::Markdown).convert(caption)
  end

end
