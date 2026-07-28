# frozen_string_literal: true

require 'date'

require_relative '../context'
require_relative 'transform'

module JekyllIS::Images::Image::SEO
  include JekyllIS::Images::Image::Transform

  IMAGE_PARAMS = 'seo_image'

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

    digest = source_digest context, source, params
    splitted = "#{ digest[0..1] }/#{ digest[2..3] }/#{ digest[4..(context.config(DIGITS_KEY).to_i + 3)] }"
    url = "/#{ context.target_path_prefix }/#{ splitted }.#{ format }"
    path = "#{ context.cache_path }/generated/#{ splitted }.#{ format }"

    full = site.in_source_dir path
    if File.file?(full)
      second = if path.start_with?('/')
        path[1..]
      else
        "/#{ path }"
      end
      static = site.static_files.find { it.relative_path == path || it.relative_path == second || it.path == path || it.path == second }
      unless static
        static = IS::StaticFile::new site, '/', url, source: path
        site.static_files << static
      end
      page.data['image'] = static.url
      return static.url
    end

    FileUtils.mkdir_p File.dirname(full)

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
      caption_img = caption_image context, splitted, params
      result = result.composite caption_img do |img|
        img.gravity 'South'
        img.geometry "+0+#{ 2 * params[:padding] }"
      end
      top = background_image context, params[:top_height], params
      result = result.composite top do |img|
        img.gravity 'North'
        img.geometry "+0+#{ params[:padding] }"
      end
      meta = meta_image context, splitted, params
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

    static = IS::StaticFile::new site, '/', url, source: path
    site.static_files << static
    page.data['image'] = static.url
    return static.url

  end

  private

  def meta_image context, splitted, params
    path = "#{ context.cache_path }/tmp/#{ splitted }-meta.png"
    full = context.site.in_source_dir path
    unless File.file?(full)
      FileUtils.mkdir_p File.dirname(full)
      MiniMagick::convert do |cmd|
        cmd.size "#{ params[:overlay_width] - 2 * params[:padding] }x#{ params[:top_height] }"
        cmd.background 'none'
        cmd.fill params[:overlay_foreground]
        cmd << 'canvas:'
        # cmd.stack do |c|
          cmd.gravity 'West'
          cmd.font params[:date_font] if params[:date_font]
          cmd.pointsize params[:date_font_size]
          cmd.annotate "+0+0", params[:date]
        # end
        # cmd.stack do |c|
          cmd.gravity 'East'
          cmd.font params[:site_font] if params[:site_font]
          cmd.pointsize params[:site_font_size]
          cmd.annotate "+0+0", params[:site]
        # end
        cmd.format 'png'
        cmd << "png:#{ full }"
      end
    end
    MiniMagick::Image::open full
  end

  def caption_image context, splitted, params
    path = "#{ context.cache_path }/tmp/#{ splitted }-caption.png"
    full = context.site.in_source_dir path
    unless File.file?(full)
      FileUtils.mkdir_p File.dirname(full)
      MiniMagick::convert do |cmd|
        cmd.size "#{ params[:overlay_width] - 2 * params[:padding] }x#{ params[:bottom_height] - 2 * params[:padding] }"
        cmd.background 'none'
        cmd.font params[:caption_font] if params[:caption_font]
        cmd.fill params[:overlay_foreground]
        cmd.gravity 'Center'
        cmd << "caption:#{ params[:caption] }"
        cmd.format 'png'
        cmd << "png:#{ full }"
      end
    end
    MiniMagick::Image::open full
  end

  def background_image context, height, params
    path = "#{ context.cache_path }/tmp/#{ params[:overlay_width] }x#{ height }-#{ params[:overlay_background] }.png"
    full = context.site.in_source_dir path
    unless File.file?(full)
      FileUtils.mkdir_p File.dirname(full)
      MiniMagick::convert do |cmd|
        cmd.size "#{ params[:overlay_width] }x#{ height }"
        cmd.background params[:overlay_background]
        cmd << 'canvas:'
        cmd.format 'png'
        cmd << "png:#{ full }"
      end
    end
    MiniMagick::Image::open full
  end

  def base_image context, source, params
    base_params = params.slice :format, :crop, :options, :salt

    digest = source_digest context, source, base_params
    splitted = "#{ digest[0..1] }/#{ digest[2..3] }/#{ digest[4..(context.config(DIGITS_KEY).to_i + 3)] }"
    path = "#{ context.cache_path }/tmp/#{ splitted }.#{ params[:format] }"
    full = context.site.in_source_dir path

    unless File.file?(full)
      FileUtils.mkdir_p File.dirname(full)
      is_svg = File.extname(source).downcase == '.svg'
      MiniMagick::convert do |cmd|
        if is_svg
          cmd << '-density' << '300'
          cmd << '-background' << 'none'
        end
        cmd << source
        cmd.crop params[:crop] if params[:crop]
        cmd.strip
        cmd.quality params[:options].quality if params[:options]&.quality
        cmd.colorspace 'sRGB'
        params[:options]&.defines&.each do |value|
          cmd.define value
        end
        cmd.format params[:format]
        cmd << "#{ params[:format] }:#{ full }"
      end
    end
    MiniMagick::Image::open full
  end

  # def caption_image context, splitted, params
  #   path = "#{ context.cache_path }/tmp/#{ splitted }.png"
  #   full = context.site.in_source_dir path
  #   FileUtils.mkdir_p File.dirname(full)
  #   unless File.file?(full)
  #     MiniMagick::convert do |cmd|
  #       cmd.size params[:seo_background_bottom_box] if params[:seo_background_bottom_box]
  #       cmd.font params[:seo_caption_font] if params[:seo_caption_font]
  #       cmd.background params[:seo_background_color] if params[:seo_background_color]
  #       cmd.fill params[:seo_font_color] if params[:seo_font_color]
  #       cmd.gravity 'Center'
  #       cmd << "caption:#{ params[:seo_caption] }"
  #       cmd.format 'png'
  #       cmd << "png:#{ full }"
  #     end
  #   end
  #   MiniMagick::Image::open full
  # end

  # def meta_image context, splitted, params
  #   # img = MiniMagick::Image::create '.png'
  #   # img.size params[:seo_background_top_box] if params[:seo_background_top_box]
  #   # if params[:seo_background_opacity]
  #   #   img.background "rgba(#{ params[:seo_background_color] }, #{ params[:seo_background_opacity] }" if params[:seo_background_color]
  #   # else
  #   #   img.background params[:seo_background_color] if params[:seo_background_color]
  #   # end
  #   # img.fill params[:seo_font_color] if params[:seo_font_color]
  #   # if params[:seo_date]
  #   #   img.combine_options do |i|
  #   #     i.gravity 'West'
  #   #     i.font params[:seo_date_font] if params[:seo_date_font]
  #   #     i.pointsize params[:seo_date_font_size].to_s if params[:seo_date_font_size]
  #   #     i.annotate "+#{ params[:seo_padding] }+0", params[:seo_date]
  #   #   end
  #   # end
  #   # if params[:seo_site]
  #   #   img.combine_options do |i|
  #   #     i.gravity 'East'
  #   #     i.font params[:seo_site_font] if params[:seo_site_font]
  #   #     i.pointsize params[:seo_site_font_size] if params[:seo_site_font_size]
  #   #     i.annotate "+#{ params[:seo_padding] }+0", params[:seo_site]
  #   #   end
  #   # end
  # end

end
