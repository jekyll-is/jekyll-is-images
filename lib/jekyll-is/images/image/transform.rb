# frozen_string_literal: true

require 'net/http'
require 'mini_magick'
require 'nokogiri'
require 'is-static-files'

require_relative 'data'
require_relative 'cache'

module JekyllIS::Images::Image::Transform

  DIGITS_KEY = 'cache_digits'

  def transform context, source, params

    # Проверяем на assets, возвращаем как есть, если так.
    return JekyllIS::Images::Image::Info[source, nil, nil] if assets?(source)

    digest = cache.source_digest(context, source, **params)
    cache.static_info context, digest, params[:format] do |full|
      source_path = if external?(source)
        # Скачиваем. Если не удается скачать, возвращаем url как есть без дополнительных данных.
        #  Исходим из того, что проблемы со скачиванием могут быть временными.
        downloaded = download_file context, source, splitted_digest, params
        unless downloaded
          context.warning "Failed download #{ source.inspect } on page #{ context.page.relative_path.inspect }"
          return JekyllIS::Images::Image::Info[source, nil, nil]
        end
        downloaded
      else
        context.site.in_source_dir source
      end

      if params[:format] == 'svg'
        convert_svg context, source_path, full, params
      else
        convert_image context, source_path, full, params
      end
    end

  rescue => ex
    context.error "Error with file #{ source.inspect } on page #{ context.page.relative_path.inspect }: #{ ex.inspect }"
  end

  private

  def cache
    JekyllIS::Images::Cache
  end

  def assets? source
    source.start_with?('/')
  end

  def external? source
    # Обрабатываем только HTTP(S) для простоты. Другие протоколы не особо актуальны.
    source.start_with?('http://') || source.start_with?('https://')
  end

  def download_file context, source, digest, params, limit = 3
    if limit <= 0
      context.warning "Too many redirects!"
      return nil
    end

    uri = URI::parse source
    path = context.site.in_source_dir "#{ context.cache_path }/downloads/#{ params[:salt] || '-' }/#{ digest }"
    return path if File.exist?(path)

    Net::HTTP::start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get::new uri
      http.request request do |response|
        case response
        when Net::HTTPSuccess
          FileUtils.mkdir_p File.dirname(path)
          File.open path, 'wb' do |file|
            response.read_body do |chunk|
              file.write chunk
            end
          end
        when Net::HTTPRedirect
          location = response['location']
          new_url = URI.join(uri.to_s, location).to_s
          return download_file context, new_url, digest, params, limit - 1
        else
          context.warning "Error while downloading #{ source.inspect } on page #{ context.page.relative_path.inspect }: #{ response.inspect }"
          return nil
        end
      end
    end
    return path
  rescue => ex
    context.warning "Error while downloading #{ source.inspect } on page #{ context.page.relative_path.inspect }: #{ ex.inspect }"
    return nil
  end

  def convert_svg context, source, full, params

    content = File.read source
    doc = Nokogiri::XML(content)
    svg = doc.at_css 'svg'
    unless svg
      context.error "Invalid SVG-file #{ source.inspect } on page #{ context.page.relative_path.inspect }"
      return nil
    end

    doc.xpath('//comment()').remove
    svg.remove_attribute('xml:space')
    svg.remove_attribute('xmlns:a')
    svg.xpath('//metadata').remove
    svg.xpath('//defs').each { |d| d.remove if d.children.empty? }

    orig_width = svg['width']
    orig_height = svg['height']
    viewbox = svg['viewBox']
    if viewbox.nil? && orig_width && orig_height
      svg['viewBox'] = "0 0 #{orig_width.to_i} #{orig_height.to_i}"
    end

    width = params[:width]
    height = params[:height]
    height = (orig_height.to_f * width.to_f / orig_width.to_f).round.to_i if width && !height
    width = (orig_width.to_f * height.to_f / orig_height.to_f).round.to_i if height && !width
    svg['width'] = width.to_s
    svg['height'] = height.to_s

    minified = svg.to_xml(indent: 0).gsub(/\n/, " ").gsub(/\s+/, " ")
    File.write full, minified

    full
  end

  def convert_image context, source, full, params

    format = params[:format]
    options = params[:options]
    width = params[:width]
    height = params[:height]
    scale = params[:scale]
    crop = params[:crop]
    fit = params[:fit]

    width = (width.to_f * scale.to_f).round.to_i if width && scale && scale != 1
    height = (height.to_f * scale.to_f).round.to_i if height && scale && scale != 1

    resize = if width && !height
      "#{ width }x>"
    elsif height && !width
      "x#{ height }>"
    elsif width && height
      if fit == 'cover'
        "#{ width }x#{ height }^>"
      else
        "#{ width }x#{ height }>"
      end
    else
      nil
    end

    is_svg = File.extname(source).downcase == '.svg'
    MiniMagick::convert do |cmd|
      if is_svg
        cmd << '-density' << '300'
        cmd << '-background' << 'none'
      end
      cmd << source
      cmd.crop crop if crop
      cmd.resize resize if resize
      cmd.strip
      cmd.quality options.quality if options.quality
      cmd.colorspace 'sRGB'
      options.defines.each do |value|
        cmd.define value
      end
      cmd.format format
      cmd << "#{ format }:#{ full }"
    end

    full
  end

end
