# frozen_string_literal: true

require_relative 'value'
require_relative '../image'

class JekyllIS::Images::Kramdown::Image < JekyllIS::Images::Kramdown::Value

  def type = :is_image

  def category
    if @figure && @figure.gallery?
      :block
    else
      :span
    end
  end

  attr_reader :figure

  def initialize context, figure: nil
    super(context)
    @figure = figure
  end

  attr_reader :alt, :src, :href, :title, :width, :height, :scale, :crop, :fit, :caption, :lazy, :salt, :format

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
    @caption = @attrs.delete('caption')
    @alt ||= @title || @caption || ''
    @title ||= @alt unless @alt.nil? || @alt.empty?
    @title ||= @caption
    @title = nil if @title == ''
    @caption = nil if @caption == ''
    @lazy = @flags.delete?('lazy')
    @salt = @attrs.delete('salt')
  end

  def to_html(overlay: { })
    transform = transform_parameters overlay
    image = JekyllIS::Images::Image::transform @context, @src, transform
    #
    # TODO: implement
  end

  private

  def transform_parameters overlay
    format = overlay['format'] || @format
    attrs = @attrs.merge(overlay['attrs'] || {})
    options = @context.options format, attrs
    width = overlay['width'] || @width
    height = overlay['height'] || @height
    scale = overlay['scale'] || @scale
    crop = overlay['crop'] || @crop
    fit = overlay['fit'] || @fit
    salt = overlay['salt'] || @salt
    { format:, options:, width:, height:, scale:, crop:, fit:, salt: }
  end

end
