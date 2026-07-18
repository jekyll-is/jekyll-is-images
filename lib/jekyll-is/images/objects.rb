# frozen_string_literal: true

require 'set'

require_relative 'error'

module JekyllIS; end
module JekyllIS::Images; end

class JekyllIS::Images::Image

  include JekyllIS::Images::Error

  attr_reader :attrs, :flags, :styles, :src, :href, :figure
  attr_accessor :id, :classes

  def initialize site, page, figure = nil
    @site = site
    @page = page
    @figure = figure
    @attrs = {}
    @flags = Set::new
    @classes = Set::new
    @styles = {}
    @id = nil
    @src = nil
    @href = nil
  end

  def apply_a element
    apply_img element
    apply_img element.children.first
  end

  def apply_img element
    el_attrs = element.attr&.dup || {}
    el_id = el_attrs.delete 'id'
    el_classes = el_attrs.delete('class')&.split(/\s/)&.to_set
    el_styles = el_attrs.delete('style')&.split(';')&.map { it.split ':' }&.select { it.is_a?(Array) && it.size == 2 }&.to_h
    el_src = el_attrs.delete 'src'
    el_href = el_attrs.delete 'href'
    el_refs = element.options&.dig(:ial, :refs)&.to_set
    @attrs.merge! el_attrs if el_attrs
    @styles.merge! el_styles if el_styles
    @flags.merge el_refs if el_refs
    @classes.merge el_classes if el_classes
    if @id && el_id
      error "Duplicate image id: #{ @id.inspect } vs #{ el_id.inspect }"
    else
      @id ||= el_id
    end
    if @src && el_src
      error "Duplicate image src: #{ @src.inspect } vs #{ el_src.inspect }"
    else
      @src ||= el_src
    end
    if @href && el_href
      error "Duplicate image href: #{ @href.inspect } vs #{ el_href.inspect }"
    else
      @href ||= el_href
    end
  end

  def to_element
    Kramdown::Element::new(:is_image, self, nil, { category: element_category })
  end

  def to_html
    Jekyll::logger.warn self.inspect
    Jekyll::logger.warn @site.static_files.inspect
    wrap_img_tag make_img_tag
  end

  def to_latex
    '' # TODO: implement
  end

  DEFAULT_OPTIONS = {
    'png'  => {},
    'jpeg' => {
      'quality' => '90'
    },
    'webp' => {
      'quality' => '80',
      'webp:method' => '6',
      'webp:progressive' => 'true',
      'webp:alpha-compression' => '1'
    },
    'avif' => {
      'quality' => '70',
      'heic:speed' => '2',
      'heic:chroma-subsampling' => '4:2:0'
    }
  }

  private

  def formats_map
    page_formats = @page.data['image_format']
    return { 'default' => page_formats.downcase } if page_formats.is_a?(String)
    page_formats = if page_formats.is_a?(Hash)
      page_formats.transform_keys { it.downcase }
    else
      {}
    end
    site_formats = @site.config.dig('is_images', 'image_format')
    site_formats = case site_formats
    when String
      { 'default' => site_formats.downcase }
    when Hash
      site_formats.transform_keys { it.downcase }
    else
      {}
    end
    site_formats.merge page_formats
  end

  def detect_format
    src_format = @src.split('?')&.first&.split('#')&.first&.split('.')&.last&.downcase
    src_format = 'jpeg' if src_format == 'jpg'
    src_format = 'tiff' if src_format == 'tif'
    @page.data['__is_images_formats_map'] ||= formats_map
    @page.data['__is_images_formats_map'][src_format] || src_format
  end

  def element_category
    if @figure && @figure.gallery?
      :block
    else
      :span
    end
  end

  def make_img_tag
    # Вычисляем трансформацию...
    width = @attrs['width']&.to_i
    height = @attrs['height']&.to_i
    scale = @attrs['scale']&.to_f
    crop = @attrs['crop']
    salt = @attrs['salt']
    fit = @attrs['fit']
    format = (@attrs['format'] || detect_format)&.downcase
    if @figure && @figure.gallery?
      item_width = (@figure.attrs['image-width'] || @page.data['gallery_image_width'] || @site.config.dig('is_images', 'gallery_image_width'))&.to_i
      item_height = (@figure.attrs['image-height'] || @page.data['gallery_image_height'] || @site.config.dig('is_images', 'gallery_image_height'))&.to_i
      item_fit = @figure.attrs['image-fit'] || @page.data['gallery_image_fit'] || @site.config.dig('is_images', 'gallery_image_fit')
      width = item_width
      height = item_height
      fit = item_fit
      scale = (@figure.attrs['image-scale'] || @page.data['gallery_image_scale'] || @site.config.dig('is_images', 'gallery_image_scale'))&.to_f
    end
    options = DEFAULT_OPTIONS[format]&.dup || {}
    options_key = format == 'avif' ? 'heic' : format
    site_options = @site.config.dig('is_images', 'format_options', format)
    if site_options
      site_options.each do |k, v|
        if k == 'quality'
          options[k] = v
        else
          options[options_key + ':' + k.tr('_', '-')] = v
        end
      end
    end
    page_options = @page.data.dig('format_options', format)
    if page_options
      page_options.each do |k, v|
        if k == 'quality'
          options[k] = v
        else
          options[options_key + ':' + k.tr('_', '-')] = v
        end
      end
    end
    @attrs.each do |k, v|
      if k == 'quality'
        options[k] = v
      elsif k.start_with?(options_key + '-')
        kk = k.sub(options_key + '-', options_key + ':')
        options[kk] = v
      end
    end
    transform = {
      format: format,
      options: options,
      width: width,
      height: height,
      scale: scale,
      crop: crop,
      fit: fit,
      salt: salt
    }
    image = wrap_image @site, @source, transform
    attributes = {}
    attributes['id'] = @id if @id
    attributes['alt'] = @attrs['alt']
    attributes['loading'] = 'lazy' if @flags.delete?('lazy')
    @classes << '__is_images_image'
    @classes << '__is_images_gallery_item' if @figure && @figure.gallery?
    @flags.each do |flag|
      @classes << "__is_images_#{flag}"
    end
    attributes['class'] = @classes.join(' ')
    @styles['--is-images-width'] = image.width
    @styles['--is-images-aspect-ratio'] = image.aspect_ratio
    @styles['--is-images-scale'] = scale if scale
    attributes['style'] = @styles.map { |k, v| "#{k}:#{v};" }.join('')
    "<img src=\"#{ image.url }\" #{ attributes.map { |k, v| "#{k}=\"#{v}\"" }.join(" ") }>"
  end

  def wrap_img_tag img_tag
    tag = @href ? 'a' : 'span'
    href = @href ? " href=\"#{ @href }\"" : ''
    title = @attrs['title'] || @attrs['caption'] || @attrs['alt']
    "<#{ tag }#{ href } class=\"__is_images_wrapper\" title=\"#{ title }\">#{ img_tag }</#{ tag }>"
  end

end

class JekyllIS::Images::Figure

  include JekyllIS::Images::Error

  attr_reader :attrs, :flags, :classes, :styles, :id, :caption, :children

  def gallery?
    @children && @children.size > 1
  end

  def initialize site, page
    @site = site
    @page = page
    @attrs = {}
    @flags = Set::new
    @classes = Set::new
    @styles = {}
    @id = nil
    @caption = nil
    @children = []
  end

  def apply_p element
    el_attrs = element.attr&.dup || {}
    el_id = el_attrs.delete 'id'
    el_classes = el_attrs.delete('class')&.split(/\s/)&.to_set
    el_styles = el_attrs.delete("style")&.split(";")&.map { it.split ":" }&.select { it.is_a?(Array) && it.size == 2 }&.to_h
    el_refs = element.options&.dig(:ial, :refs)&.to_set
    el_caption = el_attrs.delete 'caption'
    @attrs.merge! el_attrs if el_attrs
    @styles.merge! el_styles if el_styles
    @flags.merge el_refs if el_refs
    @classes.merge el_classes if el_classes
    @id = el_id
    @caption = el_caption
    @children = element.children&.map do |child|
      image = JekyllIS::Images::Image::new @site, self
      case child.type
      when :a
        image.apply_a child
      when :img
        image.apply_img child
      end
      @attrs.each do |k, v|
        if k == 'quality' || k.start_with?('webp:') || k.start_with?('heic:') || k.start_with?('jpeg:')
          image.attrs[k] ||= v
        end
      end
      image
    end
    if @children.size == 1
      image = @children.first
      @attrs.merge! image.attrs
      @flags.merge image.flags if image.flags
      @classes.merge image.classes if image.classes
      image.classes = Set::new
      @caption ||= image.attrs['caption']
    end
  end

  def to_element
    Kramdown::Element::new(:is_figure, self, nil, { category: element_category })
  end

  def to_html
    attributes = {}
    attributes['id'] = @id if @id
    @classes << '__is_images_figure'
    @classes << '__is_images_figure_gallery' if gallery?
    @flags.each do |flag|
      @classes << "__is_images_#{ flag }"
    end
    attributes['class'] = @classes.join(' ')
    attributes['style'] = @styles.map { |k, v| "#{k}:#{v};" }.join('')
    caption = @caption && @caption != '' ? "<figcaption>#{ @caption }</figcaption>" : ''
    "<figure #{ attributes.map { |k, v| "#{k}=\"#{v}\"" }.join(' ') }>\n#{ @children.map(&:to_html).join("\n") }\n</figure>"
  end

  def to_latex
    '' # TODO: implement
  end

  private

  def element_category
    :block
  end

end
