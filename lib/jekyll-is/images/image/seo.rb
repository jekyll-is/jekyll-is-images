# frozen_string_literal: true

require 'date'

require_relative '../context'
require_relative 'cache'
require_relative 'magick'

module JekyllIS::Images::Image::SEO

  include JekyllIS::Images::Image::Cache
  include JekyllIS::Images::Image::Magick

  IMAGE_PARAMS = 'seo_image'

  private_constant :IMAGE_PARAMS

  # @param [Jekyll::Site] site
  # @param [Jekyll::Page] page
  # @return [void]
  def replace_page_image site, page
    source = page.data['image']
    return source if source == nil || source.empty? || source.start_with?('/')

    context = JekyllIS::Images::Context[site, page]
    format             = context.config(IMAGE_PARAMS, 'format')
    crop               = context.config(IMAGE_PARAMS, 'crop')
    width              = context.config(IMAGE_PARAMS, 'width')&.to_i
    height             = context.config(IMAGE_PARAMS, 'height')&.to_i
    overlay_width      = context.config(IMAGE_PARAMS, 'overlay', 'width')&.to_i
    bottom_height      = context.config(IMAGE_PARAMS, 'overlay', 'bottom')&.to_i
    top_height         = context.config(IMAGE_PARAMS, 'overlay', 'top')&.to_i
    padding            = context.config(IMAGE_PARAMS, 'overlay', 'padding')&.to_i
    overlay_background = context.config(IMAGE_PARAMS, 'overlay', 'background')
    overlay_foreground = context.config(IMAGE_PARAMS, 'overlay', 'foreground')
    caption_font       = context.config(IMAGE_PARAMS, 'font', 'caption')
    date_font          = context.config(IMAGE_PARAMS, 'font', 'date')      || caption_font
    date_font_size     = context.config(IMAGE_PARAMS, 'font', 'date_size') || 24
    site_font          = context.config(IMAGE_PARAMS, 'font', 'site')      || date_font
    site_font_size     = context.config(IMAGE_PARAMS, 'font', 'site_size') || date_font_size
    salt               = context.config(IMAGE_PARAMS, 'salt')
    caption            = context.config(IMAGE_PARAMS, 'caption')           || page.data['title']
    site_title         = context.config(IMAGE_PARAMS, 'site')              || site.config['title']
    date               = context.config(IMAGE_PARAMS, 'date')              || page.data['date']
    date_format        = context.config(IMAGE_PARAMS, 'date_format')       || '%Y-%m-%d'
    date = date.strftime date_format if date.is_a?(Time) || date.is_a?(Date)
    options = context.options format
    params = {
      format:, crop:, width:, height:,
      overlay_width:, bottom_height:, top_height:, padding:,
      overlay_background:, overlay_foreground:,
      caption_font:, date_font:, date_font_size:, site_font:, site_font_size:,
      salt:,
      caption:, site: site_title, date:, date_format:,
      options:
    }

    digest = source_digest(context, source, **params)
    info = static_info context, digest, params[:format] do |full|
      begin
        base = base_image context, source, params
        base.combine_options do |img|
          img.repage '+0+0'
          img.gravity 'Center'
          img.extent "#{ width }:#{ height }"
          img.resize "#{ width }x#{ height }"
        end
        bottom = background_image context, params[:bottom_height], params
        result = base.composite bottom do |img|
          img.gravity 'South'
          img.geometry "+0+#{ params[:padding] }"
        end
        caption_img = caption_image context, params
        result = result.composite caption_img do |img|
          img.gravity 'South'
          img.geometry "+0+#{ 2 * params[:padding] }"
        end
        top = background_image context, params[:top_height], params
        result = result.composite top do |img|
          img.gravity 'North'
          img.geometry "+0+#{ params[:padding] }"
        end
        meta = meta_image context, params
        result = result.composite meta do |img|
          img.gravity 'North'
          img.geometry "+0+#{ params[:padding] }"
        end

        result.format format
        result.strip
        result.write full
      ensure
        base&.destroy!
        bottom&.destroy!
        caption_img&.destroy!
        top&.destroy!
        meta&.destroy!
        result&.destroy!
      end
    end

    page.data['image'] = info.url
    return info.url

  end

  private

  def meta_image context, params
    digest = source_digest(
      context,
      nil,
      **params.slice(:overlay_width, :padding, :top_height, :overlay_foreground, :date_font, :date_font_size, :date, :site_font, :site_font_size, :site, :salt)
    )
    magick_image context, digest, 'meta.png' do |full|
      magick_generate(
        full,
        width: (params[:overlay_width] - 2 * params[:padding]),
        height: params[:top_height],
        foreground: params[:overlay_foreground]
      ) do |cmd|
        cmd.gravity 'West'
        cmd.font params[:date_font] if params[:date_font]
        cmd.pointsize params[:date_font_size]
        cmd.annotate '+0+0', params[:date]
        cmd.gravity 'East'
        cmd.font params[:site_font] if params[:site_font]
        cmd.pointsize params[:site_font_size]
        cmd.annotate '+0+0', params[:site]
      end
    end
  end

  def caption_image context, params
    digest = source_digest(context, nil, **params.slice(:overlay_width, :padding, :bottom_height, :caption_font, :overlay_foreground, :caption, :salt))
    magick_image context, digest, 'caption.png' do |full|
      magick_generate(
        full,
        width: (params[:overlay_width] - 2 * params[:padding]),
        height: (params[:bottom_height] - 2 * params[:padding]),
        foreground: params[:overlay_foreground],
        canvas: false
      ) do |cmd|
        cmd.font params[:caption_font] if params[:caption_font]
        cmd.gravity "Center"
        cmd << "caption:#{params[:caption]}"
      end
    end
  end

  def background_image context, height, params
    used_params = params.slice :overlay_width, :overlay_background, :salt
    used_params[:height] = height
    digest = source_digest(context, nil, **used_params)
    magick_image context, digest, 'background.png' do |full|
      magick_generate full, width: params[:overlay_width], height: height, background: params[:overlay_background]
    end
  end

  def base_image context, source, params
    base_params = params.slice :format, :crop, :options, :salt
    digest = source_digest(context, source, **base_params)
    magick_image context, digest, "cover.#{ params[:format] }" do |full|
      magick_convert full, source, format: params[:format], options: params[:options], crop: params[:crop]
    end
  end

  extend self

end
