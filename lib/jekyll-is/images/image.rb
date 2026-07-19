# frozen_string_literal: true

require 'json'
require 'digest'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'fileutils'
require 'mini_magick'
require 'is-static-files'

require_relative 'error'

module JekyllIS; end
module JekyllIS::Images; end

class JekyllIS::Images::ImageInfo

  include JekyllIS::Images::Error
  include JekyllIS::Images::Config

  class << self

    def wrap_image site, source, transform
      object = new site, source, transform
      object.process
    end

    private :new

  end

  attr_reader :source, :transform
  attr_reader :width, :height, :aspect_ratio, :url

  def initialize site, source, transform
    @site = site
    @source = source
    @transform = transform
  end

  def assets?
    @source.start_with?('/')
  end

  def external?
    @source.start_with?('http://') || @source.start_with?('https://') || @source.start_with?('ftp://')
  end

  def process

    return from_file(@source, @source) if assets?

    url, path = cached_paths
    return self if from_file(url, path)

    source_path = if external?
      download_file @source, hashed: url
    else
      @site.in_source_dir @source
    end

    if @transform[:format] == 'svg'
      convert_svg source_path, path
    else
      convert_image source_path, path
    end

    from_file url, path
  rescue => ex
    error "Error with file #{ @source.inspect }: #{ ex.inspect }"
    self
  end

  private

  def from_file url, path
    full = @site.in_source_dir path
    return false unless File.exist?(full)

    if path.start_with?('/')
      second = path[1..]
    else
      second = "/#{ path }"
    end
    static = @site.static_files.find { it.relative_path == path || it.relative_path == second }
    unless static
      static = IS::StaticFile::new @site, '/', url, source: path
      @site.static_files << static
    end
    @url = static.url
    image = MiniMagick::Image::open full
      @width = image.width
      @height = image.height
      @aspect_ratio = @width.to_r / @height.to_r
      image.destroy!

    return self
  rescue => ex
    error "Error with file: #{ path.inspect }"
    return nil
  end

  def cached_paths
    sha256 = Digest::SHA256::new
    sha256.update @source
    unless external?
      full = @site.in_source_dir @source
      File::open full, 'rb' do |file|
        while chunk = file.read(65536)
          sha256.update chunk
        end
      end
    end
    sha256.update JSON::generate(transform, sort_keys: true)
    digested = "#{ sha256.hexdigest }"
    splitted = "#{ digested[0..3] }/#{ digested[4..7] }/#{ digested[8..(config(DIGITS_KEY).to_i + 7)] }.#{ @transform[:format] }"
    return [ "/#{ target_path_prefix }/#{ splitted }", "#{ cache_path }/processed/#{ splitted }" ]
  rescue => ex
    error "Error with file #{ @source.inspect }: #{ ex.inspect }"
    return [ nil, nil ]
  end

  def download_file url, limit = 3, hashed: ''
    raise 'Too many redirects!' if limit <= 0
    uri = URI::parse url
    path = @site.in_source_dir "#{ cache_path }/downloads/#{ @transform[:salt] || '-' }/#{ hashed }.src"
    return path if File.exist?(path)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get::new uri
      http.request(request) do |response|
        case response
        when Net::HTTPSuccess
          FileUtils.mkdir_p File.dirname(path)
          File.open(path, 'wb') do |file|
            response.read_body do |chunk|
              file.write chunk
            end
          end
        when Net::HTTPRedirect
          location = response['location']
          new_url = URI.join(uri.to_s, location).to_s
          return download_file new_url, limit - 1, hashed: hashed
        else
          raise "Error while download: #{ url }"
        end
      end
    end
    return path
  end

  def convert_svg source_path, target_path
    content = File.read source_path
    doc = Nokogiri::XML(content)
    svg_node = doc.at_css 'svg'
    unless svg_node
      error "Invalid SVG file: #{ source_path }"
      return nil
    end

    # Чистка
    doc.xpath("//comment()").remove
    svg_node.remove_attribute("xml:space")
    svg_node.remove_attribute("xmlns:a")
    svg_node.xpath("//metadata").remove
    svg_node.xpath("//defs").each { |d| d.remove if d.children.empty? }

    orig_width = svg_node["width"]
    orig_height = svg_node["height"]
    viewbox = svg_node["viewBox"]
    if viewbox.nil? && orig_width && orig_height
      svg_node["viewBox"] = "0 0 #{orig_width.to_i} #{orig_height.to_i}"
    end

    width = @transform[:width]
    height = @transform[:height]

    if width && !height
      height = (orig_height.to_f * width.to_f / orig_width.to_f).round.to_i
    end
    if height && !width
      width = (orig_width.to_f * height.to_f / orig_height.to_f).round.to_i
    end

    svg_node['width'] = width.to_s
    svg_node['height'] = height.to_s

    minified_xml = svg_node.to_xml(indent: 0).gsub(/\n/, " ").gsub(/\s+/, " ")
    target_full = @site.in_source_dir target_path
    FileUtils.mkdir_p File.dirname(target_full)
    File.write(target_full, minified_xml)

    target_path
  end

  def convert_image source_path, target_path
    crop = @transform[:crop]
    fit = @transform[:fit]
    width = @transform[:width]
    height = @transform[:height]
    scale = @transform[:scale]
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
    format = @transform[:format] || 'png'
    options = @transform[:options] || {}
    quality = options.quality
    image = MiniMagick::Image::open source_path
      image.combine_options do |img|
        img.crop crop if crop
        img.resize resize if resize
        img.strip
        img.quality quality if quality
        img.colorspace 'sRGB'
        options.defines.each do |value|
          img.define value
        end
      end
      image.format format
      target_full = @site.in_source_dir target_path
      FileUtils.mkdir_p File.dirname(target_full)
      image.write target_full
      image.destroy!

    target_path
  end

end
