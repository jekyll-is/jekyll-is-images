# frozen_string_literal: true

require_relative 'data'

module JekyllIS::Images::Image::Transform

  DIGITS_KEY = 'cache_digits'

  def transform context, source, params

    # Проверяем на assets, возвращаем как есть, если так.
    return from_file context, source, source if assets?

    digest = source_digest context, source, params
    splitted_digest = "#{digest[0..3]}/#{digest[4..7]}/#{digest[8..(config(DIGITS_KEY).to_i + 7)]}"
    url = "/#{target_path_prefix}/#{splitted_digest}.#{@transform[:format]}"
    path = "#{cache_path}/processed/#{splitted_digest}.#{@transform[:format]}"

    # Ищем в кэше.
    result = from_file context, url, path
    return result if result

    source_path = if external?
      # Скачиваем. Если не удается скачать, возвращаем url как есть без дополнительных данных.
      #  Исходим из того, что проблемы со скачиванием могут быть временными.
      downloaded = download_file context, source, splitted_digest, params
      unless downloaded
        context.warning "Failed download #{ source.inspect } on page #{ context.page.relative_path.inspect }"
        return JekyllIS::Images::Image::Data[source, nil, nil]
      end
      downloaded
    else
      context.site.in_source_dir source
    end

    if params[:format] == 'svg'
      convert_svg context, source_path, path, params
    else
      convert_image context, source_path, path, params
    end

    from_file context, url, path

  rescue => ex
    context.error "Error with file #{ source.inspect } on page #{ context.page.relative_path.inspect }: #{ ex.inspect }"
  end

  private

  def assets? source
    source.start_with?('/')
  end

  def external? source
    # Обрабатываем только HTTP(S) для простоты. Другие протоколы не особо актуальны.
    source.start_with?('http://') || source.start_with?('https://')
  end

  def from_file context, url, path
    full = context.site.in_source_dir path
    return nil unless File.exist?(full)

    second = if path.start_with?('/')
      path[1..]
    else
      "/#{ path }"
    end
    static = context.site.static_files.find { it.relative_path == path || it.relative_path == second }
    unless static
      static = IS::StaticFile::new context.site, '/', url, source: path
      context.site.static_files << static
    end

    w = nil
    h = nil
    magick = MiniMagick::Image::open full
    begin
      w = magick.width
      h = magick.height
    ensure
      magick.destroy!
    end

    JekyllIS::Images::Image::Data[static.url, w, w.to_r / h.to_r]
  end

  def source_digest context, source, params
    sha256 = Digest::SHA256::new
    sha256.update source
    unless external?
      full = context.site.in_source_dir source
      File::open full, "rb" do |file|
        while chunk = file.read(65536)
          sha256.update chunk
        end
      end
    end
    sha256.update JSON::generate(params, sort_keys: true)
    sha256.hexdigest
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

  def convert_svg context, source, target, params

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
    svg['width'] = width
    svg['height'] = height

    minified = svg.to_xml(indent: 0).gsub(/\n/, " ").gsub(/\s+/, " ")
    full = context.site.in_source_dir target
    FileUtils.mkdir_p File.dirname(full)
    File.write full, minified

    target
  end

  def convert_image context, source, target, params

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
      "#{ width }x"
    elsif height && !width
      "x#{ height }"
    elsif width && height
      if fit == 'cover'
        "#{ width }x#{ height }^"
      else
        "#{ width }x#{ height }"
      end
    else
      nil
    end

    image = MiniMagick::Image::open source
    begin
      image.combine_options do |img|
        img.crop crop if crop
        img.resize resize if resize
        img.strip
        img.quality options.quality if options.quality
        img.colorspace 'sRGB'
        options.defines.each do |value|
          img.define value
        end
      end
      image.format format
      full = context.site.in_source_dir target
      FileUtils.mkdir_p File.dirname(full)
      image.write full
    ensure
      image.destroy!
    end

    target
  end

end
