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

  def single?
    @children.size == 1
  end

  def gallery?
    @children.size > 1
  end

  attr_reader :caption, :modes, :shaped, :shift, :width

  def apply element
    super(element)
    @id ||= gen_id
    @caption = @attrs.delete('caption')
    @caption_position = @attrs.delete('caption-position')
    @shift = @attrs.delete('shift')&.to_i
    @up = @attrs.delete('up')&.to_i
    @width = @attrs.delete('width')&.to_i
    @modes = @attrs.delete('modes')&.split(',')&.map(&:strip) || @context.config('gallery', 'modes')&.split(',') || []
    element.children.each do |child|
      if [ :a, :img ].include?(child.type)
        image = JekyllIS::Images::Kramdown::Image::new @context, figure: self
        image.apply child
        @children << image
      end
    end

    if single?
      image = @children.first
      @caption ||= image.caption
      @caption_position ||= image.caption_position
      @attrs = image.attrs.merge(@attrs)
      # «Крадём» классы и флаги.
      @flags.merge image.flags
      image.flags.clear
      @classes.merge image.classes
      image.classes.clear
      @shaped = @flags.delete?('shape')
      @shift ||= image.shift
      @up ||= image.up
      @width ||= image.width
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

  # @private
  MODES = {
    'grid' => {
      child: 'cell',
      label: 'grid',
      display: 'grid',
      navbar: false
    },
    'slides' => {
      child: 'slide',
      label: 'slides',
      display: 'flex',
      navbar: true
    }
  }

  # TODO: Подумать над тем, чтобы вынести разные представления галерей в классы...

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
          item = generate_gallery_html(mode, hide)
          hide = true
          item
        end.join("\n")
        generate_outer_html gallery
      end
    end
  end

  private

  def gen_id
    context.page.data['__is_images_figure_count'] ||= 0
    context.page.data['__is_images_figure_count'] += 1
    "fig-#{ context.page.data['__is_images_figure_count'] }"
  end

  WIDTH_STEP = 50

  def width_class
    if @width
      nearest = (@width.to_f / WIDTH_STEP).ceil * WIDTH_STEP
      "__is_images_width_#{ nearest }"
    end
  end

  def generate_outer_html inner, single_url: nil

    classes = @classes.dup
    classes << '__is_images_figure'
    classes << '__is_images_gallery' if gallery?
    classes << '__is_images_single' if single?
    classes << '__is_images_shaped' if @shaped
    classes << width_class if @width
    @flags.each do |flag|
      classes << "__is_images__#{ flag }"
    end

    styles = @styles.dup
    styles['shape-outside'] = "url(#{ single_url })" if single_url && @shaped
    styles['--is-images-shift'] = "#{ @shift }px" if @shift
    styles['--is-images-up'] = "#{ @up }px" if @up

    fig_attrs = {}
    fig_attrs['id'] = @id if @id
    fig_attrs['class'] = classes.join(' ') unless classes.empty?
    fig_attrs['style'] = styles.map { |k, v| "#{ k }:#{ v };" }.join('') unless styles.empty?
    fig_attrs['data-modes'] = @modes.join(',') unless @modes.empty?

    data = @attrs.select { |k, _| k.start_with?('data-') }
    fig_attrs.merge! data

    if @caption
      if @caption_position == 'top'
        inner = "<figcaption>#{ process_caption(@caption) }</figcaption>\n#{ inner }"
      else
        inner = "#{ inner }\n<figcaption>#{ process_caption(@caption) }</figcaption>"
      end
    end

    if gallery? && @modes.size > 1
      inputs = ''
      labels = ''
      first = true
      @modes.each do |mode|
        inputs += "<input class=\"__is_images_tab_radio __is_images_#{ mode }_radio\" type=\"radio\" id=\"#{ @id }-#{ mode }\" name=\"mode-#{ @id }\"#{ first ? ' checked' : '' }>"
        first = false
        labels += "<label class=\"__is_images_tab_label __is_images_#{ mode }_label\" for=\"#{ @id }-#{ mode }\">#{ @context.config(mode, 'label') || MODES.dig(mode, :label) }</label>"
      end
      inner = "#{ inputs }<div class=\"__is_images_tab_control\">#{ labels }</div>#{ inner }"
    end

    "<figure #{ fig_attrs.map { |k, v| "#{ k }=\"#{ v }\"" }.join(' ') }>\n#{ inner }\n</figure>"
  end

  def generate_simple_html
    overlay = { 'mode' => 'single' }   # Мы НЕ перекрываем ничего для одиночного изображения.
    inner = @children.first.to_html(overlay: overlay)
    generate_outer_html inner, single_url: overlay['__url']
  end

  def generate_gallery_html mode, hide
    prefix = MODES.dig mode, :child
    attrs = @attrs.dup
    overlay = {}
    overlay['format'] = attrs.delete("#{ prefix }-format") || @context.config(mode, 'format')
    overlay['width']  = attrs.delete("#{ prefix }-width")  || @context.config(mode, 'width')
    overlay['height'] = attrs.delete("#{ prefix }-height") || @context.config(mode, 'height')
    overlay['scale']  = attrs.delete("#{ prefix }-scale")  || @context.config(mode, 'scale')
    overlay['crop']   = attrs.delete("#{ prefix }-crop")   || @context.config(mode, 'crop')
    overlay['fit']    = attrs.delete("#{ prefix }-fit")    || @context.config(mode, 'fit')
    overlay['lazy']   = attrs.delete("#{ prefix }-lazy")   || @context.config(mode, 'lazy')           # TODO: проверить, как работает lazy
    overlay['salt']   = attrs.delete('salt')
    overlay['attrs']  = attrs
    overlay['mode']   = prefix
    nav = ''
    navbar = MODES.dig mode, :navbar
    num = 0
    items = @children.map do |image|
      num += 1
      inner = image.to_html(overlay: overlay)
      caption = image.caption ? "<figcaption>#{ process_caption(image.caption) }</figcaption>" : ''
      if (@attrs["#{ prefix }-caption-position"] || @context.config("#{ prefix }_caption_position")) == 'top'
        inner = "#{ caption }\n#{ inner }"
      else
        inner = "#{ inner }\n#{ caption }"
      end
      if navbar
        nav += "<a href=\"\##{ @id }-#{ mode }-#{ num }\">#{ num }</a>"
      end
      "<figure class=\"__is_images_#{ prefix }_figure\" id=\"#{ @id }-#{ mode }-#{ num }\">#{ inner }</figure>"
    end
    cnt_styles = {}
    cnt_styles["--is-images-#{ prefix }-width"] = "#{ overlay['width'] }px" if overlay['width']
    cnt_styles["--is-images-#{ prefix }-height"] = "#{ overlay['height'] }px" if overlay['height']
    cnt_styles['--is-images-display'] = MODES.dig mode, :display
    # cnt_styles['display'] = 'none' if hide
    cnt_classes = []
    cnt_classes << "__is_images_#{ mode }_container"
    cnt_classes << '__is_images_tab_block'
    if @modes.size == 1
      cnt_classes << '__is_images_only'
    else
      cnt_classes << "__is_images_#{ mode }_item"
    end
    cnt_attrs = {}
    cnt_attrs['class'] = cnt_classes.join(' ')
    cnt_attrs['style'] = cnt_styles.map { |k, v| "#{ k }:#{ v };" }.join('')
    # if navbar
      nav = "<nav class=\"__is_images_gallery_navbar #{ modes.size == 1 ? '__is_images_only' : "__is_images_#{ mode }_item" }\">#{ nav }</nav>"
    # end
    "<div #{ cnt_attrs.map { |k, v| "#{ k }=\"#{ v }\"" }.join(' ') }>#{ items.join("\n") }</div>#{ nav }"
  end

  def process_caption caption
    @context.markdown.convert(caption).chomp.delete_prefix('<p>').delete_suffix('</p>')
  end

end
