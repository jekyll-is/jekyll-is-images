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
    if @children.size > 1 && @modes.empty?
      @context.error "Invalid gallery (without modes) on page #{ @context.page.relative_path.inspect }"
    end
  end

  INNER_PREFIX = {
    'grid' => 'cell',
    'slides' => 'slide'
  }

  def to_html
    case @children.size
    when 0
      @context.error "Invalid figure (without images) on page #{ @context.page.relative_path.inspect }"
      ''
    when 1
      generate_simple_html
    else
      if @modes.empty?
        @context.error "Invalid gallery (without modes) on page #{ @context.page.relative_path.inspect }"
        ''
      else
        @context.page.data['__is_images_has_galleries'] = true
        hide = false
        gallery = @modes.map do |mode|
          item = generate_gallery_html(mode, INNER_PREFIX[mode], hide)
          hide = true
          item
        end.join("\n")
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

    if @caption
      if @caption_position == 'top'
        inner = "<figcaption>#{ process_caption(@caption) }</figcaption>\n#{ inner }"
      else
        inner = "#{ inner }\n<figcaption>#{ process_caption(@caption) }</figcaption>"
      end
    end

    "<figure #{ fig_attrs.map { |k, v| "#{ k }=\"#{ v }\"" }.join(' ') }>\n#{ inner }\n</figure>"
  end

  def generate_simple_html
    overlay = { 'mode' => 'single' }   # Мы НЕ перекрываем ничего для одиночного изображения.
    generate_outer_html @children.first.to_html(overlay: overlay)
  end

  def generate_gallery_html mode, prefix, hide
    attrs = @attrs.dup
    overlay = {}
    overlay['format'] = attrs.delete("#{ prefix }-format") || @context.config(mode, 'format')
    overlay['width']  = attrs.delete("#{ prefix }-width")  || @context.config(mode, 'width')
    overlay['height'] = attrs.delete("#{ prefix }-height") || @context.config(mode, 'height')
    overlay['scale']  = attrs.delete("#{ prefix }-scale")  || @context.config(mode, 'scale')
    overlay['crop']   = attrs.delete("#{ prefix }-crop")   || @context.config(mode, 'crop')
    overlay['fit']    = attrs.delete("#{ prefix }-fit")    || @context.config(mode, 'fit')
    overlay['salt']   = attrs.delete('salt')
    overlay['attrs']  = attrs
    overlay['mode']   = prefix
    items = @children.map do |image|
      inner = image.to_html(overlay: overlay)
      caption = image.caption ? "<figcaption>#{ process_caption(image.caption) }</figcaption>" : ''
      if (@attrs["#{ prefix }-caption-position"] || @context.config("#{ prefix }_caption_position")) == 'top'
        inner = "#{ caption }\n#{ inner }"
      else
        inner = "#{ inner }\n#{ caption }"
      end
      "<figure class=\"__is_images_#{ prefix }_figure\">#{ inner }</figure>"
    end
    cnt_styles = {}
    cnt_styles["--is-image-#{ prefix }-width"] = "#{ overlay['width'] }px" if overlay['width']
    cnt_styles["--is-image-#{ prefix }-height"] = "#{ overlay['height'] }px" if overlay['height']
    cnt_styles['display'] = 'none' if hide
    cnt_classes = []
    cnt_classes << "__is_images_#{ mode }_container"
    cnt_attrs = {}
    cnt_attrs['class'] = cnt_classes.join(' ')
    cnt_attrs['style'] = cnt_styles.map { |k, v| "#{ k }:#{ v };" }.join('')
    "<div #{ cnt_attrs.map { |k, v| "#{ k }=\"#{ v }\"" }.join(' ') }>#{ items.join("\n") }</div>"
  end

  def process_caption caption
    @context.markdown.convert(caption).chomp.delete_prefix('<p>').delete_suffix('</p>')
  end

end
