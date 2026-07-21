# frozen_string_literal: true

require_relative 'value'
require_relative '../image'

class JekyllIS::Images::Kramdown::Image < JekyllIS::Images::Kramdown::Value

  def type = :is_image
  def category = :span

  attr_reader :figure

  def initialize context, figure: nil
    super(context)
    @figure = figure
  end

  attr_reader :alt, :src, :href, :title, :width, :height, :scale, :crop, :fit, :shift, :caption, :lazy, :salt, :format, :caption_position

  def apply element
    super(element)
    super(element.children.first) if element.type == :a
    @alt = @attrs.delete('alt')
    @src = @attrs.delete('src')
    @format = @attrs.delete('format') || @context.detect_format(@src)
    @href = @attrs.delete('href') || context.config('default_link')
    @href = false  if [ '0', 'false', 'no', 'none' ].include?(@href)
    @href = 'view' if [ '1', 'true', 'yes', 'auto' ].include?(@href)
    @title = @attrs.delete('title')
    @width = @attrs.delete('width')&.to_i
    @height = @attrs.delete('height')&.to_i
    @scale = @attrs.delete('scale')&.to_f
    @crop = @attrs.delete('crop')
    @fit = @attrs.delete('fit')
    @shift = @attrs.delete('shift')&.to_i
    @caption = @attrs.delete('caption')
    @alt ||= @title || @caption || ''
    @title ||= @alt unless @alt.nil? || @alt.empty?
    @title ||= @caption
    @title = nil if @title == ''
    @caption = nil if @caption == ''
    @lazy = @flags.delete?('lazy')
    @salt = @attrs.delete('salt')
    @caption_position = @attrs.delete('caption-position')
  end

  def to_html(overlay: {})

    @context.page.data['__is_images_has_images'] = true
    transform = transform_parameters overlay
    image = JekyllIS::Images::Image::transform @context, @src, transform

    img_styles = @styles.dup
    if transform[:width]
      img_styles['--is-images-width'] = "#{ transform[:width] }px"
    elsif transform[:height] && image.aspect_ratio
      img_styles['--is-images-width'] = "#{ transform[:height] * image.aspect_ratio }px"
    end
    img_styles['--is-images-aspect-ratio'] = image.aspect_ratio.to_s if image.aspect_ratio
    img_styles['--is-images-scale'] = transform[:scale] if transform[:scale]
    img_styles['--is-images-fit'] = transform[:fit] if transform[:fit]
    img_styles['--is-images-shift'] = "#{ @shift }px" if @shift

    img_classes = @classes.dup
    img_classes << '__is_images_image'
    img_classes << "__is_images_#{ overlay['mode'] }" if overlay['mode']
    @flags.each do |flag|
      img_classes << "__is_images__#{ flag }"
    end

    img_attrs = {}
    img_attrs['id'] = @id if @id
    img_attrs['src'] = image.url
    img_attrs['alt'] = @alt if @alt
    img_attrs['class'] = img_classes.join(' ')
    img_attrs['style'] = img_styles.map { |k, v| "#{ k }:#{ v };" }.join('')
    img_attrs['loading'] = 'lazy' if @lazy
    img_attrs['data-scale'] = transform[:scale] || 1
    img_attrs['data-caption'] = @caption if @caption

    img = "<img #{ img_attrs.map { |k, v| "#{ k }=\"#{ v }\"" }.join(' ') }>"

    wrp_tag = 'a'
    wrp_attrs = {}
    if @href == 'view'
      if @src.start_with?('http://') || @src.start_with?('https://')
        wrp_attrs['href'] = @src
      else
        view_transform = view_transform_parameters overlay
        image = JekyllIS::Images::Image::transform @context, @src, view_transform
        wrp_attrs['href'] = image.url
      end
    elsif @href
      wrp_attrs['href'] = @href
    else
      wrp_tag = 'span'
    end
    wrp_attrs['title'] = @title if @title
    wrp_attrs['class'] = '__is_images_wrapper'

    "<#{ wrp_tag } #{ wrp_attrs.map { |k, v| "#{ k }=\"#{ v }\"" }.join(' ') }>#{ img }</#{ wrp_tag }>"
  end

  private

  def transform_parameters overlay
    attrs = @attrs.merge(overlay['attrs'] || {})
    format = overlay['format'] || @format
    options = @context.options format, attrs
    width = overlay['width'] || @width
    height = overlay['height'] || @height
    scale = overlay['scale'] || @scale
    crop = overlay['crop'] || @crop
    fit = overlay['fit'] || @fit
    salt = overlay['salt'] || @salt
    { format:, options:, width:, height:, scale:, crop:, fit:, salt: }
  end

  def view_transform_parameters overlay
    attrs = @attrs.merge(overlay['attrs'] || {})
    format = attrs['view-format'] || @context.config('view', 'format') || @format
    options = @context.options format, attrs
    width = attrs['view-width'] || @context.config('view', 'width')
    height = attrs['view-height'] || @context.config('view', 'height')
    crop = attrs['view-crop'] || @context.config('view', 'crop')
    fit = attrs['view-fit'] || @context.config('view', 'fit')
    salt = overlay['salt'] || @salt
    { format:, options:, width:, height:, crop:, fit:, salt: }
  end

end
